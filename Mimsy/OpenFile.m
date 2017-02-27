#import "OpenFile.h"

#import "AppDelegate.h"
#import "Decode.h"
#import "DirectoryController.h"
#import "Glob.h"
#import "Languages.h"
#import "TextController.h"
#import "TranscriptController.h"
#import "Utils.h"

@implementation OpenFile

+ (NSArray<MimsyPath*>*)resolvePath:(MimsyPath*)path rootedAt:(MimsyPath*)root
{
    __block NSMutableArray* result = [NSMutableArray new];
    
    if ([path isAbsolute])
    {
        [result addObject:path];
    }
    else
    {
        // First see if we have any open windows that match the path. (This will often happen
        // and speeds up the resolve a lot when using remote shares).
        [TextController enumerate:^(TextController* controller, bool* stop)
        {
            if ([controller.path hasStem:path])
            {
                [result addObject:controller.path];
                *stop = true;
            }
        }];
        
        // If that failed then search for the file.
        if (result.count == 0)
        {
            AppDelegate* app = (AppDelegate*) [NSApp delegate];
            [app enumerateWithDir:root recursive:true error:^(NSString* _Nonnull err)
            {
                NSString* mesg = [NSString stringWithFormat:@"Error resolving '%@': %@", root, err];
                [TranscriptController writeError:mesg];
            }
            predicate:^BOOL(MimsyPath* _Nonnull dir, NSString* _Nonnull fileName)
            {
                MimsyPath* candidate = [dir appendWithComponent:fileName];
                return [candidate hasStem:path];
            }
            callback:^(MimsyPath* _Nonnull dir, NSArray<NSString*>* _Nonnull fileNames)
            {
                for (NSString* fileName in fileNames)
                {
                    MimsyPath* p = [dir appendWithComponent:fileName];
                    [result addObject:p];
                }
            }];
        }
    }
    
    return result;
}

+ (bool)shouldOpenFiles:(NSUInteger)numFiles
{
	const NSUInteger MaxFiles = 5;
	
	bool open = true;
	
	if (numFiles > MaxFiles)
	{
		NSString* title = [NSString stringWithFormat:@"%lu files are being opened", numFiles];
		NSString* message = @"Do you really want to open all of these files?";
		
		NSAlert* alert = [NSAlert new];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert setInformativeText:title];
		[alert setMessageText:message];
		[alert addButtonWithTitle:@"No"];
		[alert addButtonWithTitle:@"Yes"];
		
		NSInteger button = [alert runModal];
		open = button == NSAlertSecondButtonReturn;
	}
	
	return open;
}

+ (bool)tryOpenPath:(MimsyPath*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width
{
	bool can = [self _mimsyCanOpen:path];
	
	if (can)
		[self openPath:path atLine:line atCol:col withTabWidth:width];
	
	return can;
}

+ (void)openPath:(MimsyPath*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width completed:(CompletionBlock)completed
{
    if (![self _dontOpenWithMimsy:path])
    {
        NSURL* url = path.asURL;
        NSDocumentController* dc = [NSDocumentController sharedDocumentController];
        [dc openDocumentWithContentsOfURL:url display:YES completionHandler:
         ^(NSDocument* document, BOOL documentWasAlreadyOpen, NSError* error)
         {
             (void) document;
             (void) documentWasAlreadyOpen;
             
             if (!error && line != -1)
             {
                 // Note that we need to scroll even if the document was already open
                 // so that errors are scrolled into view.
                 ASSERT(document.windowControllers.count == 1);
                 TextController* controller = (TextController*) document.windowControllers[0];
                 [controller showLine:line atCol:col withTabWidth:width];
                 
                 if (completed)
                     completed(controller);
             }
             else if (error && error.code != NSUserCancelledError)
             {
                 // We'll attempt to open everything (except blacklisted globs) in
                 // Mimsy. This is good because there are all sorts of weird text
                 // files that people may want to edit. If we cannot open it within
                 // Mimsy then we'll open it like the Finder does (this will normally
                 // only happen for binary files).
                 bool opened = [[NSWorkspace sharedWorkspace] openFile:path.asString];
                 if (!opened)
                 {
                     NSString* reason = [error localizedFailureReason];
                     NSString* mesg = [NSString stringWithFormat:@"Couldn't open '%@': %@", url, reason];
                     [TranscriptController writeError:mesg];
                 }
             }
         }
         ];
    }
    else
    {
        [[NSWorkspace sharedWorkspace] openFile:path.asString];
    }
}

+ (void)openPath:(MimsyPath*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width
{
    [OpenFile openPath:path atLine:line atCol:col withTabWidth:width completed:nil];
}

+ (void)openPath:(MimsyPath*)path withRange:(NSRange)range
{
	if (![self _dontOpenWithMimsy:path])
	{
		NSURL* url = path.asURL;
		NSDocumentController* dc = [NSDocumentController sharedDocumentController];
		[dc openDocumentWithContentsOfURL:url display:YES completionHandler:
			 ^(NSDocument* document, BOOL documentWasAlreadyOpen, NSError* error)
			 {
				 (void) document;
				 
				 if (!error && range.location != NSNotFound)
				 {
					 LayoutCallback callback = ^(TextController *controller)
					 {
                         // Need a bit of a delay to allow the document to fully load
                         // (especially when documents are mounted remotely via something
                         // like SMB).
                         dispatch_queue_t main = dispatch_get_main_queue();
                         dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 250*NSEC_PER_MSEC);
                         dispatch_after(delay, main, ^{
                             [controller.getTextView scrollRangeToVisible:range];
                             [controller.getTextView showFindIndicatorForRange:range];
                             [controller.getTextView setSelectedRange:range];
                         });
					 };
					 
					 TextController* controller = (TextController*) document.windowControllers[0];
					 if (documentWasAlreadyOpen)
						 callback(controller);
					 else
						 [controller registerBlockWhenLayoutCompletes:callback];
				 }
				 else if (error && error.code != NSUserCancelledError)
				 {
					 bool opened = [[NSWorkspace sharedWorkspace] openFile:path.asString];
					 if (!opened)
					 {
						 NSString* reason = [error localizedFailureReason];
						 NSString* mesg = [NSString stringWithFormat:@"Couldn't open '%@': %@", url, reason];
						 [TranscriptController writeError:mesg];
					 }
				 }
			 }];
	}
	else
	{
		[[NSWorkspace sharedWorkspace] openFile:path.asString];
	}
}

+ (bool)_mimsyCanOpen:(MimsyPath*)path
{
	// Check to see if the user has marked the file as something he doesn't
	// want to open with Mimsy.
	if ([self _dontOpenWithMimsy:path])
		return false;
	
	// If the file is part of an open directory then check the directory prefs.
	DirectoryController* controller = [DirectoryController getController:path];
	if (controller && [controller shouldOpen:path])
		return true;

	// See if the extension matches one of our languages. Contents is used to
	// match shebangs within script files without an extension. But if it's a
	// text file we'll wind up opening it anyway so we'll avoid the work of
	// reading the file twice in the common case where the extension is enough
	// to figure out whether we can open it.
	if ([Languages findWithFileName:path.lastComponent contents:@""])
		return true;

	// Fallback to checking to see if the file can be read as text.
	NSData* data = [NSData dataWithContentsOfFile:path.asString];
	Decode* decode = data ? [[Decode alloc] initWithData:data] : nil;
	return decode.text != nil;
}

+ (bool)_dontOpenWithMimsy:(MimsyPath*)path
{
    if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath:path.asString])
        return true;
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    NSString* fileName = [path lastComponent];
    NSString* setting = [app.layeredSettings stringValue:@"DontOpenWithMimsy" missing:@""];
	if (setting.length > 0)
	{
		NSArray* patterns = [setting splitByString:@" "];
		Glob* glob = [[Glob alloc] initWithGlobs:patterns];
		return [glob matchName:fileName] == 1;
	}
	else
	{
		return false;
	}
}

@end
