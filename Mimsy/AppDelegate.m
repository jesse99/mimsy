#import "AppDelegate.h"

#import "Assert.h"
#import "Languages.h"
#import "SelectStyleController.h"
#import "WindowsDatabase.h"

@implementation AppDelegate

// Note that windows will still be open when this is called.
- (void)applicationWillTerminate:(NSNotification *)notification
{
	(void) notification;
	LOG_INFO("App", "Terminating");
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
	(void) notification;
	
	ASSERT([NSThread isMultiThreaded]);
	LOG_DEBUG("App", "Finished launching");

	[WindowsDatabase setup];
	[Languages setup];
}

- (void) applicationDidBecomeActive:(NSNotification*)notification
{
	(void) notification;
	
	[self reloadIfChanged];
}

- (void) reloadIfChanged
{
	for (id doc in [[NSDocumentController sharedDocumentController] documents])
	{
		if ([doc respondsToSelector:@selector(reloadIfChanged)])
			[doc reloadIfChanged];
	}
}

- (IBAction)setStyle:(id)sender
{
	(void) sender;
	[SelectStyleController open];
}

- (IBAction)openAsBinary:(id)sender
{
	(void) sender;
	
	NSOpenPanel* panel = [NSOpenPanel new];
	[panel setTitle:@"Open as Binary"];
	[panel setTreatsFilePackagesAsDirectories:YES];
	[panel setAllowsMultipleSelection:YES];
	
	NSInteger button = [panel runModal];
	
	if (button == NSOKButton)
	{
		for (NSURL* url in [panel URLs])
		{
			[self openBinary:url];
		}
	}
}

- (void) openBinary:(NSURL*)url
{
	NSDocumentController* controller = [NSDocumentController sharedDocumentController];
	
	NSDocument* doc = [controller documentForURL:url];
	if (doc == nil)
	{
		NSError* error = nil;
		doc = [controller makeDocumentWithContentsOfURL:url ofType:@"binary" error:&error];
		if (error)
		{
			[NSAlert alertWithError:error];
			return;
		}
		
		[controller addDocument:doc];
		[doc makeWindowControllers];
	}
	
	[doc showWindows];
}

@end
