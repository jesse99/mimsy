#import "AppDelegate.h"

#import "AppSettings.h"
#import "ConfigParser.h"
#import "Constants.h"
#import "DirectoryController.h"
#import "DirectoryWatcher.h"
#import "FindInFilesController.h"
#import "FindResultsController.h"
#import "FunctionalTest.h"
#import "Glob.h"
#import "HelpItem.h"
#import "InstallFiles.h"
#import "Language.h"
#import "Languages.h"
#import "LocalSettings.h"
#import "Logger.h"
#import "Paths.h"
#import "SearchSite.h"
#import "SelectStyleController.h"
#import "StartupScripts.h"
#import "TextController.h"
#import "TimeMachine.h"
#import "TranscriptController.h"
#import "Utils.h"
#import "WindowsDatabase.h"

void initLogGlobs()
{
	NSString* path = [Paths installedDir:@"settings"];
	path = [path stringByAppendingPathComponent:@"logging.mimsy"];
	
	NSError* error = nil;
	NSMutableArray* patterns = [NSMutableArray new];
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (parser)
	{
		[parser enumerate:
		 ^(ConfigParserEntry* entry)
		 {
			 if ([entry.key isEqualToString:@"DontLog"])
				 [patterns addObject:entry.value];
			 else
				 LOG("Warning", "Ignoring %s in %s", STR(entry.key), STR(path));
		 }
		 ];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load %@:\n%@.", path, [error localizedFailureReason]];
		LOG("Error", "%s", STR(mesg));
	}
	
	Glob* glob = [[Glob alloc] initWithGlobs:patterns];
	setTopicGlob(glob);
}

typedef void (^NullaryBlock)();

@implementation AppDelegate
{
	DirectoryWatcher* _languagesWatcher;
	DirectoryWatcher* _settingsWatcher;
	DirectoryWatcher* _stylesWatcher;
	DirectoryWatcher* _scriptsStartupWatcher;
	DirectoryWatcher* _transformsWatcher;
	DirectoryWatcher* _helpWatcher;
	
	NSMutableDictionary* _pendingBlocks;
	NSArray* _helpFileItems;
	NSArray* _helpSettingsItems;
}

- (id)init
{
	self = [super init];
	
	if (self)
	{
//		ASSERT([NSThread isMultiThreaded]);
		
		_settings = [[LocalSettings alloc] initWithFileName:@"app.mimsy"];
		_pendingBlocks = [NSMutableDictionary new];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appSettingsChanged:) name:@"AppSettingsChanged" object:nil];
		
		[self _installFiles];
		[self _loadSettings];
		[self _loadHelpFiles];
		[self _addTransformItems];
		[self _watchInstalledFiles];
		[StartupScripts setup];
		[WindowsDatabase setup];
		[Languages setup];
		
		initFunctionalTests();
	}
	
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	UNUSED(notification);
	
	__weak AppDelegate* this = self;
	[[NSApp helpMenu] setDelegate:this];
}

// Note that windows will still be open when this is called.
- (void)applicationWillTerminate:(NSNotification *)notification
{
	UNUSED(notification);
	LOG("App", "Terminating");
}

- (void)_executeSelector:(NSString*)name
{
	NullaryBlock block = self->_pendingBlocks[name];
	@try
	{
		block();
	}
	@catch (NSException *exception)
	{
		NSString* mesg = [NSString stringWithFormat:@"Internal '%@' error: %@", name, exception.reason];
		[TranscriptController writeError:mesg];
	}
	[self->_pendingBlocks removeObjectForKey:name];
}

+ (void)execute:(NSString*)name withSelector:(SEL)selector withObject:(id) object afterDelay:(NSTimeInterval)delay
{
	AppDelegate* delegate = [NSApp delegate];
	
	if (!delegate->_pendingBlocks[name])
	{
		NullaryBlock block = ^()
			{
				#pragma clang diagnostic push
				#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
				
				id result = [object performSelector:selector];
				ASSERT(result == nil);
				
				#pragma clang diagnostic pop
			};
		
		delegate->_pendingBlocks[name] = block;
		[delegate performSelector:@selector(_executeSelector:) withObject:name afterDelay:delay];
	}
}

- (void)openLatestInTimeMachine:(id)sender
{
	UNUSED(sender);
	[TimeMachine openLatest];
}

- (void)openTimeMachine:(id)sender
{
	UNUSED(sender);
	[TimeMachine openFiles];
}

- (void)findInFiles:(id)sender
{
	UNUSED(sender);
	
	[FindInFilesController show];
}

- (void)findNextInFiles:(id)sender
{
	UNUSED(sender);
	
	FindResultsController* controller = [FindResultsController frontmost];
	if (controller)
		[controller openNext];
}

- (void)findPreviousInFiles:(id)sender
{
	UNUSED(sender);
	
	FindResultsController* controller = [FindResultsController frontmost];
	if (controller)
		[controller openPrevious];
}

- (void)searchSite:(id)sender
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
				LOG("App", "Searching using %s", path.UTF8String);
				[[NSWorkspace sharedWorkspace] openURL:url];
			}
			else
			{
				[TranscriptController writeError:[NSString stringWithFormat:@"Couldn't create the URL: %@", path]];
			}
		}
	}
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
	UNUSED(notification);
	
	[self reloadIfChanged];
}

- (void)appSettingsChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
	[SearchSite updateMainMenu:self.searchMenu];
	
	NSMutableArray* helps = [NSMutableArray new];
	[AppSettings enumerate:@"ContextHelp" with:
		^(NSString *fileName, NSString *value)
		{
			NSError* error = nil;
			HelpItem* help = [[HelpItem alloc] initFromSetting:fileName value:value err:&error];
			if (help)
			{
				[helps addObject:help];
			}
			else
			{
				NSString* reason = [error localizedFailureReason];
				NSString* mesg = [NSString stringWithFormat:@"Error parsing ContextHelp from %@: %@", fileName, reason];
				[TranscriptController writeError:mesg];
			}
		}];
	_helpSettingsItems = helps;
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

// This isn't used (the app is part of the responder chain, but not the app delegate).
// But we need a getHelpContext declaration to shut the compiler up.
- (NSArray*)getHelpContext
{
	return @[];
}

// Returns an array of active context names from most to least specific.
- (NSArray*)_getActiveHelpContexts
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

- (void)_addMatchingHelp:(NSArray*)candidates context:(NSString*)context to:(NSMutableArray*)helps
{
	for (HelpItem* candidate in candidates)
	{
		if ([candidate matchesContext:context])
			[helps addObject:candidate];
	}
}

- (NSArray*)_getHelpForActiveContexts
{
	NSArray* contexts = [self _getActiveHelpContexts];	
	
	NSMutableArray* helps = [NSMutableArray new];
	for (NSString* context in contexts)
	{
		NSMutableArray* temp = [NSMutableArray new];
		[self _addMatchingHelp:_helpFileItems context:context to:temp];
		[self _addMatchingHelp:_helpSettingsItems context:context to:temp];
		[temp sortUsingComparator:
			 ^NSComparisonResult(HelpItem* lhs, HelpItem* rhs)
			 {
				 return [rhs.title compare:lhs.title];
			 }];
		
		[helps addObjectsFromArray:temp];
	}
	
	return helps;
}

- (void)openHelpFile:(id)sender
{
	NSURL* url = [sender representedObject];
	[self openWithMimsy:url];
}

- (NSArray*)_createHelpMenuItems:(NSArray*)helps
{
	NSMutableArray* items = [NSMutableArray new];
	
	for (HelpItem* help in helps)
	{
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:help.title action:@selector(openHelpFile:) keyEquivalent:@""];
		[item setRepresentedObject:help.url];
		[items addObject:item];
	}
	
	return items;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
	if (menu == [NSApp helpMenu])
	{
		NSArray* helps = [self _getHelpForActiveContexts];
		
		[menu removeAllItems];
		NSArray* items = [self _createHelpMenuItems:[helps reverse]];	// most general first so items don't move around as much
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

- (void)openWithMimsy:(NSURL*)url
{
	if ([url isFileURL])
	{
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES completionHandler:
		 ^(NSDocument* document, BOOL documentWasAlreadyOpen, NSError* error)
		 {
			 UNUSED(document, documentWasAlreadyOpen);
			 if (error && error.code != NSUserCancelledError)
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
	else if (sel == @selector(findNextInFiles:))
	{
		FindResultsController* controller = [FindResultsController frontmost];
		enabled = controller && controller.canOpenNext;
	}
	else if (sel == @selector(findPreviousInFiles:))
	{
		FindResultsController* controller = [FindResultsController frontmost];
		enabled = controller && controller.canOpenPrevious;
	}
	else if (sel == @selector(searchSite:))
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
	else if (sel == @selector(_runTransformFile:))
	{
		NSWindow* window = [NSApp mainWindow];
		if (window)
		{
			id controller = window.windowController;
			if (controller && [controller respondsToSelector:@selector(getTextView)])
			{
				NSTextView* view = [controller getTextView];
				NSRange range = [view selectedRange];
				enabled = range.length > 0;
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

- (void)_runTransformFile:(id)sender
{
	TextController* controller = [TextController frontmost];
	NSTextView* view = [controller getTextView];
	NSRange range = view ? [view selectedRange] : NSZeroRange;
	if (range.length > 0)
	{
		NSString* selection = [view.textStorage.string substringWithRange:range];
		NSString* path = [sender representedObject];
				
		NSPipe* input = [NSPipe new];
		NSFileHandle* handle = input.fileHandleForWriting;
		[handle writeData:[NSData dataWithBytes:(void*)selection.UTF8String length:range.length]];
		[handle closeFile];

		NSTask* task = [NSTask new];
		[task setLaunchPath:path];
		[task setStandardInput:input];
		[task setStandardOutput:[NSPipe new]];
		[task setStandardError:[NSPipe new]];
		
		NSString* stdout = nil;
		NSString* stderr = nil;
		NSError* err = [Utils run:task stdout:&stdout stderr:&stderr timeout:MainThreadTimeOut];
		
		if (!err)
		{
			if ([view shouldChangeTextInRange:range replacementString:stdout])
			{
				[view replaceCharactersInRange:range withString:stdout];
				[view.undoManager setActionName:path.stringByDeletingPathExtension.lastPathComponent];
				[view didChangeText];
			}
		}
		else
		{
			NSString* reason = [err localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Error running transform: %@\n", reason];
			[TranscriptController writeError:mesg];
		}
	}
}

- (void) _removeTransformItems
{
	NSMenu* menu = self.textMenu;
	while (true)
	{
		NSMenuItem* item = [menu itemAtIndex:menu.numberOfItems-1];
		if (item.action == @selector(_runTransformFile:))
		{
			[menu removeItem:item];
		}
		else
		{
			break;
		}
	}
}

+ (void) _addTransformItemsToMenu:(NSMenu*)menu
{
	NSString* transformsDir = [Paths installedDir:@"transforms"];
	NSError* error = nil;
	[Utils enumerateDir:transformsDir glob:nil error:&error block:
	 ^(NSString* path)
	 {
		 NSString* name = path.lastPathComponent;
		 if ([[NSFileManager defaultManager] isExecutableFileAtPath:path])
		 {
			 if (![path endsWith:@".old"])
			 {
				 NSString* title = [name stringByDeletingPathExtension];
				 NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(_runTransformFile:) keyEquivalent:@""];
				 [item setRepresentedObject:path];
				 
				[menu addItem:item];
			 }
		 }
		 else
		 {
			 LOG("Mimsy", "Skipping %s (it isn't executable)\n", name.UTF8String);
		 }
	 }
	 ];
	
	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		LOG("Error", "Error adding transforms to Text menu: %s\n", STR(reason));
	}
}

- (void) _addTransformItems
{
	NSMenu* menu = self.textMenu;
	if (menu)
		[AppDelegate _addTransformItemsToMenu:menu];
}

+ (void)appendContextMenu:(NSMenu*)menu
{
	[menu addItem:[NSMenuItem separatorItem]];
	[AppDelegate _addTransformItemsToMenu:menu];
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
		[installer addSourceItem:@"transforms"];
		[installer install];
	}
	else
	{
		NSString* mesg = @"Failed to install support files: URLsForDirectory:NSApplicationSupportDirectory failed to find any directories.";
		[TranscriptController writeError:mesg];
	}
}

- (void)_loadHelpFiles
{
	NSString* helpDir = [Paths installedDir:@"help"];
	Glob* glob = [[Glob alloc] initWithGlob:@"*-*.*"];
	
	NSError* error = nil;
	NSMutableArray* items = [NSMutableArray new];
	[Utils enumerateDir:helpDir glob:glob error:&error block:
		 ^(NSString* path)
		 {
			 NSError* err = nil;
			 HelpItem* help = [[HelpItem alloc] initFromPath:path err:&err];
			 if (help)
			 {
				 [items addObject:help];
			 }
			 else
			 {
				NSString* reason = [err localizedFailureReason];
				NSString* mesg = [NSString stringWithFormat:@"Failed to load '%@': %@", path, reason];
				[TranscriptController writeError:mesg];
			 }
		 }];
	
	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Error enumerating help directory: %@", reason];
		[TranscriptController writeError:mesg];
	}

	_helpFileItems = items;
}

- (void)_loadSettings
{
	_settings = [[LocalSettings alloc] initWithFileName:@"app.mimsy"];
	
	NSString* path = [Paths installedDir:@"settings"];
	path = [path stringByAppendingPathComponent:@"app.mimsy"];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		NSError* error = nil;
		ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
		if (parser)
		{
			[parser enumerate:
				 ^(ConfigParserEntry* entry)
				 {
					 [_settings addKey:entry.key value:entry.value];
				 }];
		}
		else
		{
			NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load %@:\n%@.", path, [error localizedFailureReason]];
			LOG("Error", "%s", STR(mesg));
		}
	}
}

- (void)_watchInstalledFiles
{
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
	
	dir = [Paths installedDir:@"transforms"];
	_transformsWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSString* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			[self _removeTransformItems];
			[self _addTransformItems];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TransformsChanged" object:self];
		}
	];
	
	dir = [Paths installedDir:@"settings"];
	_settingsWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSString* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			initLogGlobs();
			[self _loadSettings];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsChanged" object:self];
		}
		];
	
	dir = [Paths installedDir:@"help"];
	_helpWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSString* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			[self _loadHelpFiles];
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

	dir = [Paths installedDir:@"transforms"];
	_stylesWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(NSString* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TransformsChanged" object:self];
		}
	];
}

@end
