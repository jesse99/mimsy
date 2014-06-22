#import "OpenFile.h"

#import "AppSettings.h"
#import "Assert.h"
#import "Decode.h"
#import "DirectoryController.h"
#import "Glob.h"
#import "Languages.h"
#import "StringCategory.h"
#import "TextController.h"
#import "TranscriptController.h"

@implementation OpenFile

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

+ (bool)tryOpenPath:(NSString*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width
{
	bool can = [self _mimsyCanOpen:path];
	
	if (can)
		[self openPath:path atLine:line atCol:col withTabWidth:width];
	
	return can;
}

+ (void)openPath:(NSString*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width
{
	if (![self _dontOpenWithMimsy:path.lastPathComponent])
	{
		NSURL* url = [NSURL fileURLWithPath:path];
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
					 }
					 else if (error && error.code != NSUserCancelledError)
					 {
						 // We'll attempt to open everything (except blacklisted globs) in
						 // Mimsy. This is good because there are all sorts of weird text
						 // files that people may want to edit. If we cannot open it within
						 // Mimsy then we'll open it like the Finder does (this will normally
						 // only happen for binary files).
						 bool opened = [[NSWorkspace sharedWorkspace] openFile:path];
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
		[[NSWorkspace sharedWorkspace] openFile:path];
	}
}

+ (void)openPath:(NSString*)path withRange:(NSRange)range
{
	if (![self _dontOpenWithMimsy:path.lastPathComponent])
	{
		NSURL* url = [NSURL fileURLWithPath:path];
		NSDocumentController* dc = [NSDocumentController sharedDocumentController];
		[dc openDocumentWithContentsOfURL:url display:YES completionHandler:
			 ^(NSDocument* document, BOOL documentWasAlreadyOpen, NSError* error)
			 {
				 (void) document;
				 
				 if (!error && range.location != NSNotFound)
				 {
					 LayoutCallback callback = ^(TextController *controller)
					 {
						 [controller.getTextView scrollRangeToVisible:range];
						 [controller.getTextView showFindIndicatorForRange:range];
						 [controller.getTextView setSelectedRange:range];
					 };
					 
					 TextController* controller = (TextController*) document.windowControllers[0];
					 if (documentWasAlreadyOpen)
						 callback(controller);
					 else
						 [controller registerBlockWhenLayoutCompletes:callback];
				 }
				 else if (error && error.code != NSUserCancelledError)
				 {
					 bool opened = [[NSWorkspace sharedWorkspace] openFile:path];
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
		[[NSWorkspace sharedWorkspace] openFile:path];
	}
}

+ (bool)_mimsyCanOpen:(NSString*)path
{
	// Check to see if the user has marked the file as something he doesn't
	// want to open with Mimsy.
	NSString* name = [path lastPathComponent];
	if ([self _dontOpenWithMimsy:name])
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
	if ([Languages findWithFileName:name contents:@""])
		return true;

	// Fallback to checking to see if the file can be read as text.
	NSData* data = [NSData dataWithContentsOfFile:path];
	Decode* decode = data ? [[Decode alloc] initWithData:data] : nil;
	return decode.text != nil;
}

+ (bool)_dontOpenWithMimsy:(NSString*)fileName
{
	NSString* setting = [AppSettings stringValue:@"DontOpenWithMimsy" missing:nil];
	if (setting)
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
