#import "AppDelegate.h"

#import "Assert.h"
#import "ConfigParser.h"
#import "DirectoryController.h"
#import "DirectoryWatcher.h"
#import "FunctionalTest.h"
#import "Glob.h"
#import "InstallFiles.h"
#import "Language.h"
#import "Languages.h"
#import "Logger.h"
#import "Paths.h"
#import "SelectStyleController.h"
#import "StartupScripts.h"
#import "TranscriptController.h"
#import "Utils.h"
#import "WindowsDatabase.h"

void initLogLevels(void)
{
	NSString* path = [Paths installedDir:@"settings"];
	path = [path stringByAppendingPathComponent:@"logging.mimsy"];
	
	NSError* error = nil;
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (parser)
	{
		[parser enumerate:
		 ^(ConfigParserEntry* entry)
		 {
			 setTopicLevel(entry.key.UTF8String, entry.value.UTF8String);
		 }
		 ];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load %@:\n%@.", path, [error localizedFailureReason]];
		LOG_ERROR("Mimsy", "%s", STR(mesg));
	}
}

@implementation AppDelegate
{
	DirectoryWatcher* _languagesWatcher;
	DirectoryWatcher* _settingsWatcher;
	DirectoryWatcher* _stylesWatcher;
	DirectoryWatcher* _scriptsStartupWatcher;
}

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

	__weak AppDelegate* this = self;
	[[NSApp helpMenu] setDelegate:this];
	
	[self _installFiles];
	[self _watchInstalledFiles];
	[StartupScripts setup];
	[WindowsDatabase setup];
	[Languages setup];
	
	initFunctionalTests();
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
	(void) notification;
	
	[self reloadIfChanged];
}

// Don't open a new unitled window when we are activated and don't have a window open.
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication*)sender
{
	(void) sender;
	return NO;
}

+ (void)restoreWindowWithIdentifier:(NSString*)identifier state:(NSCoder*)state completionHandler:(void (^)(NSWindow*, NSError*))handler
{
	(void) state;
	
	if ([identifier isEqualToString:@"DirectoryWindow3"])
	{
		NSWindowController* controller = [[DirectoryController alloc] initWithDir:@":restoring:"];
		handler(controller.window, NULL);
	}
	else
	{
		NSString* mesg = [NSString stringWithFormat:@"Don't know how to restore a %@ window", identifier];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		NSError* err = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
		handler(nil, err);
	}
}

- (void)reloadIfChanged
{
	for (id doc in [[NSDocumentController sharedDocumentController] documents])
	{
		if ([doc respondsToSelector:@selector(reloadIfChanged)])
			[doc reloadIfChanged];
	}
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	if (menu == [NSApp helpMenu])
	{
		NSArray* contexts = [self _buildHelpContext];
		NSArray* items = [self _getHelpSettingsItems:contexts];
		items = [items arrayByAddingObjectsFromArray:[self _getHelpLangItems:contexts]];
		items = [items arrayByAddingObjectsFromArray:[self _getHelpFileItems:contexts]];
		
		[menu removeAllItems];
		for (NSMenuItem* item in items)
		{
			[menu addItem:item];
		}
	}
}

- (void)runFTests:(id)sender
{
	(void) sender;
	runFunctionalTests();
}

- (void)runFTest:(id)sender
{
	runFunctionalTest([sender representedObject]);
}

- (void)openHelpFile:(id)sender
{
	NSURL* url = [sender representedObject];
	
	if ([url isFileURL])
	{
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES completionHandler:
			^(NSDocument* document, BOOL documentWasAlreadyOpen, NSError* error)
			{
				(void) document;
				(void) documentWasAlreadyOpen;
				if (error)
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
		if (![[NSWorkspace sharedWorkspace] openURL:url])
			NSBeep();
	}
}

- (void)openInstalled:(id)sender
{
	(void) sender;
	
	NSString* path = [Paths installedDir:nil];
	[[NSWorkspace sharedWorkspace] openFile:path];
}

- (IBAction)setStyle:(id)sender
{
	(void) sender;
	[SelectStyleController open];
}

- (void)openDirectory:(id)sender
{
	(void) sender;
	
	NSOpenPanel* panel = [NSOpenPanel new];
	[panel setTitle:@"Open Directory"];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	[panel setCanCreateDirectories:YES];
	[panel setAllowsMultipleSelection:YES];
	
	NSInteger button = [panel runModal];
	if (button == NSOKButton)
	{
		for (NSURL* url in panel.URLs)
		{
			(void) [[DirectoryController alloc] initWithDir:[url path]];
		}
	}	
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

- (void)openBinary:(NSURL*)url
{
	NSDocumentController* controller = [NSDocumentController sharedDocumentController];
	
	NSDocument* doc = [controller documentForURL:url];
	if (doc == nil)
	{
		NSError* error = nil;
		doc = [controller makeDocumentWithContentsOfURL:url ofType:@"binary" error:&error];
		if (!doc)
		{
			[NSAlert alertWithError:error];
			return;
		}
		
		[controller addDocument:doc];
		[doc makeWindowControllers];
	}
	
	[doc showWindows];
}

// This isn't used (the app is part of the responder chain, but not the app delegate).
// But we need a getHelpContext declaration to shut the compiler up.
- (NSArray*)getHelpContext
{
	return @[];
}

- (NSArray*)_buildHelpContext
{
	NSMutableArray* result = [NSMutableArray new];
	
	id target = [NSApp targetForAction:@selector(getHelpContext)];
	while (target)
	{
		if ([target respondsToSelector:@selector(getHelpContext)])
		{
			id tmp = target;
			[result addObjectsFromArray:[tmp getHelpContext]];
		}
		
		if ([target isKindOfClass:[NSResponder class]])	// using isKindOfClass because @selector(nextResponder) didn't work with Xcode 4.6
			target = [target nextResponder];
		else
			target = nil;
	}
	[result addObject:@"app"];
	
	return result;
}

- (NSArray*)_getHelpSettingsItems:(NSArray*)context
{
	NSMutableArray* items = [NSMutableArray new];
	
	__block NSError* error = nil;
	NSString* helpDir = [Paths installedDir:@"settings"];
	NSString* path = [helpDir stringByAppendingPathComponent:@"help.mimsy"];
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (!error)
	{
		__block NSMutableDictionary* helpDict = [NSMutableDictionary new];
		
		[parser enumerate:
			 ^(ConfigParserEntry* entry)
			 {
				 NSMutableArray* help = helpDict[entry.key];
				 if (!help)
				 {
					 help = [NSMutableArray new];
					 helpDict[entry.key] = help;
				 }
				 
				 if (![Language parseHelp:entry.value help:help] && !error)
				 {
					 NSString* mesg = [NSString stringWithFormat:@"malformed help on line %ld: expected '[<title>]<url or full path>'", entry.line];
					 NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
					 error = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
				 }
			 }
		 ];
		
		if (!error)
		{
			for (NSString* name in context)
			{
				NSArray* help = helpDict[name];
				if (help)
					[self _processHelpLangItems:items help:help];
			}
		}
	}
	
	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Couldn't load settings/help.mimsy: %@", reason];
		[TranscriptController writeError:mesg];
	}
	
	return items;
}

- (NSArray*)_getHelpLangItems:(NSArray*)context
{
	NSMutableArray* items = [NSMutableArray new];
	
	for (NSString* name in context)
	{
		Language* lang = [Languages findWithlangName:name];
		if (lang && lang.help)
			[self _processHelpLangItems:items help:lang.help];
	}
	
	return items;
}

- (void)_processHelpLangItems:(NSMutableArray*)items help:(NSArray*)help
{
	for (NSUInteger i = 0; i < help.count;)
	{
		NSString* title = help[i++];
		NSURL* url = help[i++];
		
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openHelpFile:) keyEquivalent:@""];
		[item setRepresentedObject:url];
		[items addObject:item];
	}
}

- (NSArray*)_getHelpFileItems:(NSArray*)context
{
	__block NSMutableArray* items = [NSMutableArray new];
	
	NSString* helpDir = [Paths installedDir:@"help"];
	for (NSString* name in context)
	{
		NSString* pattern = [NSString stringWithFormat:@"%@-*.rtf", name];
		Glob* glob = [[Glob alloc] initWithGlob:pattern];
		
		NSError* error = nil;
		[Utils enumerateDir:helpDir glob:glob error:&error block:
		 ^(NSString* path)
		 {
			 // file names look like "app-Overview.rtf"
			 NSMenuItem* item = [self _createHelpItem:path];
			 if (item)
				 [items addObject:item];
		 }
		 ];
		
		if (error)
		{
			NSString* reason = [error localizedFailureReason];
			LOG_ERROR("Mimsy", "Error building help menu: %s\n", STR(reason));
		}
	}
	
	return items;
}

- (NSMenuItem*)_createHelpItem:(NSString*)path
{
	NSMenuItem* item = nil;
	
	NSString* fileName = [path lastPathComponent];
	NSRange range = [fileName rangeOfString:@"-"];
	if (range.location != NSNotFound)
	{
		NSString* title = [[fileName stringByDeletingPathExtension] substringFromIndex:range.location+1];
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openHelpFile:) keyEquivalent:@""];

		NSURL* url = [NSURL fileURLWithPath:path];
		[item setRepresentedObject:url];
	}
	else
	{
		LOG_WARN("Mimsy", "'%s' is in the help directory, but not formatted as '<context>-<item name>.rtf", STR(fileName));
	}
	
	return item;
}

- (void)_installFiles
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSArray* urls = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
	if (urls.count > 0)
	{
		NSString* path = [urls[0] path];
		path = [path stringByAppendingPathComponent:@"Mimsy"];
		
		InstallFiles* installer = [InstallFiles new];
		[installer initWithDstPath:path];
		[installer addSourceItem:@"help"];
		[installer addSourceItem:@"languages"];
		[installer addSourceItem:@"scripts"];
		[installer addSourceItem:@"settings"];
		[installer addSourceItem:@"styles"];
		[installer install];
	}
	else
	{
		NSString* mesg = @"Failed to install support files: URLsForDirectory:NSApplicationSupportDirectory failed to find any directories.";
		[TranscriptController writeError:mesg];
	}
}

- (void)_watchInstalledFiles
{
	// files in the help directory are loaded when used so no need to watch those
	
	NSString* dir = [Paths installedDir:@"languages"];
	_languagesWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSArray* paths)
		{
			(void) paths;
			[Languages languagesChanged];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"LanguagesChanged" object:self];
		}
	];

	dir = [Paths installedDir:@"scripts/startup"];
	_scriptsStartupWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSArray* paths)
		{
			(void) paths;
			[StartupScripts setup];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"StartupScriptsChanged" object:self];
		}
	];
	
	dir = [Paths installedDir:@"settings"];
	_settingsWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSArray* paths)
		{
			(void) paths;
			initLogLevels();
			[[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsChanged" object:self];
		}
	];

	dir = [Paths installedDir:@"styles"];
	_stylesWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSArray* paths)
		{
			(void) paths;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"StylesChanged" object:self];
		}
	];
}

@end
