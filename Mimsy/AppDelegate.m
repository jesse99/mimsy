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
#import "StringCategory.h"
#import "TextController.h"
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
	UNUSED(notification);
	LOG_INFO("App", "Terminating");
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
	UNUSED(notification);
	
	ASSERT([NSThread isMultiThreaded]);
	LOG_DEBUG("App", "Finished launching");

	__weak AppDelegate* this = self;
	[[NSApp helpMenu] setDelegate:this];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowBecameMain:) name:NSWindowDidBecomeMainNotification object:nil];
	
	[self _installFiles];
	[self _watchInstalledFiles];
	[StartupScripts setup];
	[WindowsDatabase setup];
	[Languages setup];
	
	initFunctionalTests();
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
	UNUSED(notification);
	
	[self reloadIfChanged];
}

- (void)windowBecameMain:(NSNotification*)notification
{
	UNUSED(notification);
	
	// This seems to be called a bit too early: before NSApplication's orderedWindows
	// has been updated. So we wait a little while to ensure that we can get the
	// right TextController for the new window.
	[self performSelector:@selector(updateSearchers) withObject:nil afterDelay:0.250];
}

- (void)updateSearchers
{
	NSMutableArray* sources = [NSMutableArray new];
	NSMutableArray* searchers = [NSMutableArray new];

	[self _findSearchers:searchers sources:sources];
	[self _clearSearchers];
	[self _addSearchers:searchers sources:sources];
}

- (void)_findSearchers:(NSMutableArray*)searchers sources:(NSMutableArray*)sources
{	
	// First add lnguage specific searchers. 
	TextController* text = [TextController frontmost];
	if (text && text.language)
	{
		NSString* source = [NSString stringWithFormat:@"%@ language file", text.language.name];
		for (NSString* searcher in text.language.searchIn)
		{
			[sources addObject:source];
			[searchers addObject:searcher];
		}
	}
	
	// Then add project specific searchers.
	DirectoryController* directory = [DirectoryController getCurrentController];
	if (directory)
	{
		NSString* source = [directory.path stringByAppendingPathComponent:@".mimsy.rtf"];
		for (NSString* searcher in directory.searchIn)
		{
			[sources addObject:source];
			[searchers addObject:searcher];
		}
	}

	// And finally add google.
	[sources addObject:@"AppDelegate.m"];		// TODO: probably should pull this from app setting file
	[searchers addObject:@"[Google]http://www.google.com/search?q=${TEXT}"];
}

- (void)_clearSearchers
{
	NSMenu* menu = self.searchMenu;
	while (menu && menu.numberOfItems > 0)
	{
		NSInteger index = menu.numberOfItems-1;
		NSMenuItem* item = [menu itemAtIndex:index];
		if (item.action == @selector(_searchSite:))
			[menu removeItemAtIndex:index];
		else
			break;
	}
}

- (void)_addSearchers:(NSArray*)searchers sources:(NSArray*)sources
{
	ASSERT(searchers.count == sources.count);
	
	for (NSUInteger i = 0; i < searchers.count; ++i)
	{
		NSString* label;
		NSString* template;
		[self _extractFrom:searchers[i] label:&label andURL:&template source:sources[i]];

		NSString* title = [NSString stringWithFormat:@"Search in %@", label];
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(_searchSite:) keyEquivalent:@""];
		[item setRepresentedObject:template];
		
		NSMenu* menu = self.searchMenu;
		if (menu)
			[menu addItem:item];
	}
}

- (void)_searchSite:(id)sender
{
	NSWindow* window = [NSApp mainWindow];
	if (window)
	{
		id controller = window.windowController;
		if (controller && [controller respondsToSelector:@selector(getTextView)])
		{
			NSTextView* view = [controller getTextView];
			NSRange range = [view selectedRange];
			NSString* selection = [view.textStorage.string substringWithRange:range];
			selection = [selection replaceCharacters:@"*{}\\:<>/+.() %?&" with:@"%20"];	// http://www.google.com/support/forum/p/Google%20Analytics/thread?tid=7d92c1d4cd30a285&hl=en
			selection = [selection replaceCharacters:@"#" with:@"%23"];

			NSString* template = [sender representedObject];
			NSString* path = [template stringByReplacingOccurrencesOfString:@"${TEXT}" withString:selection];
			NSURL* url = [NSURL URLWithString:path];
			if (url)
			{
				LOG_INFO("App", "Searching using %s", path.UTF8String);
				[[NSWorkspace sharedWorkspace] openURL:url];
			}
			else
			{
				[TranscriptController writeError:[NSString stringWithFormat:@"Couldn't create the URL: %@", path]];
			}
		}
	}
}

// value is formatted as: [label]url with ${TEXT}
- (void)_extractFrom:(NSString*)text label:(NSString**)label andURL:(NSString**)template source:(NSString*)source
{
	NSRange r1 = [text rangeOfString:@"["];
	NSRange r2 = [text rangeOfString:@"]"];
	NSString* error = nil;
	if (r1.location != NSNotFound && r2.location != NSNotFound && r2.location > r1.location)
	{
		NSString* name = [text substringWithRange:NSMakeRange(r1.location+1, r2.location-r1.location-1)];
		if (name.length == 0)
		{
			error = [NSString stringWithFormat:@"empty label for '%@'.", text];
			goto failed;
		}
		
		NSString* path = [text substringFromIndex:r2.location+1];
		if (![path contains:@"${TEXT}"])
		{
			error = [NSString stringWithFormat:@"expected '${TEXT}' in the url portion of '%@'.", text];
			goto failed;
		}
		
		NSString* p = [path stringByReplacingOccurrencesOfString:@"${TEXT}" withString:@"xxx"];
		NSURL* url = [NSURL URLWithString:p];
		if (!url)
		{
			error = [NSString stringWithFormat:@"expected '[label]url' but found malformed url: '%@'.", text];
			goto failed;
			
		}
		
		*label = name;
		*template = path;
	}
	else
	{
		error = [NSString stringWithFormat:@"expected '[label]url' but found: '%@'.", text];
	}
	
failed:
	if (error)
		[TranscriptController writeError:[NSString stringWithFormat:@"Failed to parse searcher from %@: %@", source, error]];
}

// Don't open a new unitled window when we are activated and don't have a window open.
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication*)sender
{
	UNUSED(sender);
	return NO;
}

+ (void)restoreWindowWithIdentifier:(NSString*)identifier state:(NSCoder*)state completionHandler:(void (^)(NSWindow*, NSError*))handler
{
	UNUSED(state);
	
	if ([identifier isEqualToString:@"DirectoryWindow3"])
	{
		NSWindowController* controller = [DirectoryController open:@":restoring:"];
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
	UNUSED(sender);
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
				UNUSED(document, documentWasAlreadyOpen);
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
	UNUSED(sender);
	
	NSString* path = [Paths installedDir:nil];
	[[NSWorkspace sharedWorkspace] openFile:path];
}

- (IBAction)setStyle:(id)sender
{
	UNUSED(sender);
	[SelectStyleController open];
}

- (void)openDirectory:(id)sender
{
	UNUSED(sender);
	
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
			(void) [DirectoryController open:[url path]];
		}
	}	
}

- (IBAction)openAsBinary:(id)sender
{
	UNUSED(sender);
	
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

// Seems that we need to define this to shut the compiler up (having it declared in DirectoryController
// isn't enough).
- (void)openDirSettings:(id)sender
{
	UNUSED(sender);
	ASSERT(false);
}

- (void)build:(id)sender
{
	DirectoryController* controller = [DirectoryController getCurrentController];
	if (controller)
		[controller buildTarget:sender];
	else
		NSBeep();
}

- (NSTextView*)getTextView
{
	return nil;
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	BOOL enabled = NO;
	
	SEL sel = [item action];
	if (sel == @selector(openDirSettings:))
	{
		[item setTitle:@"Open Directory Settings"];
		enabled = NO;
	}
	else if (sel == @selector(build:))
	{
		DirectoryController* controller = [DirectoryController getCurrentController];
		if (controller && controller.canBuild)
		{
			[item setTitle:[NSString stringWithFormat:@"Build %@", controller.buildTargetName]];
			enabled = YES;
		}
		else
		{
			[item setTitle:@"Build"];
		}
	}
	else if (sel == @selector(_searchSite:))
	{
		NSWindow* window = [NSApp mainWindow];
		if (window)
		{
			id controller = window.windowController;
			if (controller && [controller respondsToSelector:@selector(getTextView)])
			{
				NSTextView* view = [controller getTextView];
				NSRange range = [view selectedRange];
				enabled = range.length > 1;
			}
		}
	}
	else if ([self respondsToSelector:sel])
	{
		enabled = YES;
	}
	else if ([super respondsToSelector:@selector(validateMenuItem:)])
	{
		enabled = [super validateMenuItem:item];
	}
	
	return enabled;
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
		[installer addSourceItem:@"builders"];
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
		^(NSString* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			[Languages languagesChanged];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"LanguagesChanged" object:self];
		}
	];

	dir = [Paths installedDir:@"scripts/startup"];
	_scriptsStartupWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSString* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			[StartupScripts setup];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"StartupScriptsChanged" object:self];
		}
	];
	
	dir = [Paths installedDir:@"settings"];
	_settingsWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSString* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			initLogLevels();
			[[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsChanged" object:self];
		}
	];

	dir = [Paths installedDir:@"styles"];
	_stylesWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSString* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			[[NSNotificationCenter defaultCenter] postNotificationName:@"StylesChanged" object:self];
		}
	];
}

@end
