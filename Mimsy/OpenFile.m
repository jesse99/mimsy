#import "OpenFile.h"

#import "Assert.h"
#import "Languages.h"
#import "TextController.h"
#import "TranscriptController.h"

@implementation OpenFile

+ (bool)shouldOpenFiles:(NSUInteger)numFiles
{
	const NSUInteger MaxFiles = 20;
	
	bool open = true;
	
	if (numFiles > MaxFiles)
	{
		NSString* title = [NSString stringWithFormat:@"%lu files are being opened", numFiles];
		NSString* message = @"Do you really want to open all of these files?";
		
		NSInteger button = NSRunAlertPanel(title, message, @"No", @"Yes", nil);
		open = button == NSAlertAlternateReturn;
	}
	
	return open;
}

+ (void)openPath:(NSString*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width
{
	if ([self _mimsyCanOpen:path])
	{
		NSURL* url = [NSURL fileURLWithPath:path];
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES completionHandler:
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
				 else if (error)
				 {
					 NSString* reason = [error localizedFailureReason];
					 NSString* mesg = [NSString stringWithFormat:@"Couldn't open '%@': %@", url, reason];
					 [TranscriptController writeError:mesg];
				 }
			 }
		 ];
	}
	else
	{
		if (![[NSWorkspace sharedWorkspace] openFile:path])
		{
			NSBeep();
		}
	}
}

+ (bool)_mimsyCanOpen:(NSString*)path
{
	// See if the extension is one we want to handle.
	// TODO: might want a rich-text language so users can have more
	// control over this (or a pref).
	NSString* ext = [path pathExtension];
	if ([ext isEqualToString:@"rtf"])
		return true;

	// See if the extension matches one of our languages. Unfortunately
	// some languages require oeeking at the file contents in order to
	// know if it's really one of their files so we have to read the file.
	NSString* name = [path lastPathComponent];
	NSString* contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
	if (contents && [Languages findWithFileName:name contents:contents])
		return true;

	// There are files that we want to open that don't have useful extensions
	// (notably shebanged scripts). These cases should be handled by conditional
	// globals in the language files.
	return false;
}

@end
