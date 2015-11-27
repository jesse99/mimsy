#import "AppDelegate.h"

//#import <OSXFUSE/OSXFUSE.h>

#import "AppHandlers.h"
#import "ConfigParser.h"
#import "Constants.h"
#import "DirectoryController.h"
#import "DirectoryWatcher.h"
#import "ExtensionListener.h"
#import "Extensions.h"
#import "FindInFilesController.h"
#import "FindResultsController.h"
#import "FunctionalTest.h"
#import "Glob.h"
#import "HelpItem.h"
#import "InstallFiles.h"
#import "Language.h"
#import "Languages.h"
#import "Logger.h"
#import "MenuCategory.h"
#import "OpenSelection.h"
#import "Paths.h"
#import "Plugins.h"
#import "ProcFileSystem.h"
#import "ProcFiles.h"
#import "SearchSite.h"
#import "SelectStyleController.h"
#import "SpecialKeys.h"
#import "StartupScripts.h"
#import "TextController.h"
#import "TimeMachine.h"
#import "TranscriptController.h"
#import "Utils.h"
#import "WindowsDatabase.h"
#import "Mimsy-Swift.h"


void initLogGlobs()
{
	NSString* path = [Paths installedDir:@"settings"];
	path = [path stringByAppendingPathComponent:@"logging.mimsy"];
	
	NSError* error = nil;
	NSMutableArray* doPatterns = [NSMutableArray new];
	NSMutableArray* dontPatterns = [NSMutableArray new];
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (parser)
	{
		[parser enumerate:
		 ^(ConfigParserEntry* entry)
		 {
			 if ([entry.key isEqualToString:@"DontLog"])
				 [dontPatterns addObject:entry.value];
			 else if ([entry.key isEqualToString:@"ForceLog"])
				 [doPatterns addObject:entry.value];
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
	
	Glob* glob = [[Glob alloc] initWithGlobs:dontPatterns];
	setDontLogGlob(glob);
	
	glob = [[Glob alloc] initWithGlobs:doPatterns];
	setForceLogGlob(glob);
}

@implementation AppDelegate
{
#if OLD_EXTENSIONS
    ProcFileReadWrite* _beepFile;
    ProcFileKeyStoreR* _appSetting;
    ProcFileKeyStoreR* _appSettings;
    ProcFileReader* _cachesPath;
    ProcFileReader* _installedFilesPath;
    ProcFileReader* _resourcesPath;
    ProcFileReader* _extensionSettingsPath;
    ProcFileReadWrite* _logFile;
    ProcFileReadWrite* _pasteBoardText;
	ProcFileSystem* _procFileSystem;
	ProcFileReader* _versionFile;
    ProcFileAction* _copyItem;
    ProcFileAction* _deleteItem;
    ProcFileAction* _trashItem;
    ProcFileAction* _showItem;
    ProcFileAction* _newDirectory;
    ProcFileAction* _openAsBinary;
    ProcFileAction* _openLocal;
    ProcFileAction* _addMenuItem;
    ProcFileAction* _setMenuItemTitle;
    ProcFileAction* _disableMenuItem;
    ProcFileAction* _enableMenuItem;
#endif
    
	DirectoryWatcher* _languagesWatcher;
    DirectoryWatcher* _settingsWatcher;
	DirectoryWatcher* _extensionSettingsWatcher;
	DirectoryWatcher* _stylesWatcher;
	DirectoryWatcher* _scriptsStartupWatcher;
	DirectoryWatcher* _extensionsWatcher;
	DirectoryWatcher* _transformsWatcher;
	DirectoryWatcher* _helpWatcher;
#if OLD_EXTENSIONS
    ProcFileKeyStoreRW* _keyStoreFile;
#endif
    
	NSMutableDictionary* _pendingBlocks;
	NSArray* _helpFileItems;
	NSArray* _helpSettingsItems;
    NSMutableArray* _recentDirectories; // array [timestamp, path]
    
    bool _mounted;
    NSString* _mountPath;
    bool _launched;
    NSMutableDictionary* _items;
    Settings* _settings;
}

- (id)init
{
	self = [super init];
	
	if (self)
	{
//		ASSERT([NSThread isMultiThreaded]);
		
        _settings = [[Settings alloc] init:@"app.mimsy" context:self];
		_pendingBlocks = [NSMutableDictionary new];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newMainWindow:) name:NSWindowDidBecomeMainNotification object:nil];
		
#if OLD_EXTENSIONS
		NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
		[center addObserver:self selector:@selector(_didMount:)
					   name:kGMUserFileSystemDidMount object:nil];
		[center addObserver:self selector:@selector(_mountFailed:)
					   name:kGMUserFileSystemMountFailed object:nil];

        _procFileSystem = [ProcFileSystem new];
#endif
        _items = [NSMutableDictionary new];
        
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        _recentDirectories = [NSMutableArray new];
        [_recentDirectories addObjectsFromArray:[defaults arrayForKey:@"recent-directories"]];

        _inited = true;
#if OLD_EXTENSIONS
        initFunctionalTests();
#endif
        registerAppHandlers();
	}
	
	return self;
}

- (void)logLine:(NSString*)topic text:(NSString*)text
{
    LOG(STR(topic), "%s", STR(text));
}

#if OLD_EXTENSIONS
- (void)_didMount:(NSNotification*)notification
{
    NSDictionary* userInfo = [notification userInfo];
    _mountPath = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
    
    _mounted = true;
    if (_launched)
        [self _postInit];
}

- (void)_handleMount
{
	NSString* path = _mountPath;
	LOG("ProcFS", "mounted %s", STR(path));
	
    NSString* esPath = [Paths installedDir:@"settings"];
    esPath = [esPath stringByAppendingPathComponent:@"extensions"];
   _extensionSettingsWatcher = [[DirectoryWatcher alloc] initWithPath:esPath latency:1.0 block:
         ^(NSString* path, FSEventStreamEventFlags flags)
         {
             UNUSED(path, flags);
             
             static bool invoking = false;
             if (!invoking)
             {
                 invoking = true;
                 [Extensions invokeNonBlocking:@"/extension-settings-changed"];
                 invoking = false;
             }
         }
        ];
    
	_beepFile = [[ProcFileReadWrite alloc]
         initWithDir:^NSString *{return @"/";}
         fileName:@"beep"
         readStr:^NSString* {return @"";}
         writeStr:^(NSString* str)
         {
             UNUSED(str);
             LOG("App", "beeping for %s", STR([Extensions invoked]));
             NSBeep();
         }];
    
    _appSetting = [[ProcFileKeyStoreR alloc] initWithDir:^NSString *{return @"/setting";}
        keys:^NSArray *{
            return [_settings getKeys];
        } values:^NSString *(NSString *key) {
            return [_settings stringValue:key missing:@""];
        }];
    
    _appSettings = [[ProcFileKeyStoreR alloc] initWithDir:^NSString *{return @"/settings";}
        keys:^NSArray *{
            return [_settings getKeys];
        } values:^NSString *(NSString *key) {
            NSArray* values = [_settings stringValues:key];
            return [values componentsJoinedByString:@"\f"];
        }];
    
    _cachesPath = [[ProcFileReader alloc]
          initWithDir:^NSString *{return @"/";}
          fileName:@"caches-path"
          readStr:^NSString*
          {
              return [Paths caches];
          }];
    
    _installedFilesPath = [[ProcFileReader alloc]
          initWithDir:^NSString *{return @"/";}
          fileName:@"installed-files-path"
          readStr:^NSString*
          {
              return [Paths installedDir:nil];
          }];
    
    _resourcesPath = [[ProcFileReader alloc]
          initWithDir:^NSString *{return @"/";}
          fileName:@"resources-path"
          readStr:^NSString*
          {
              NSString* path = [[[NSBundle mainBundle] resourceURL] path];
              return path;
          }];
    
    _extensionSettingsPath = [[ProcFileReader alloc]
        initWithDir:^NSString *{return @"/";}
        fileName:@"extension-settings-path"
        readStr:^NSString*
        {
            if (![[NSFileManager defaultManager] fileExistsAtPath:esPath isDirectory:NULL])
            {
                NSError* error = nil;
                if (![[NSFileManager defaultManager] createDirectoryAtPath:esPath withIntermediateDirectories:TRUE attributes:nil error:&error])
                {
                    LOG("Error", "failed to create '%s': %s", STR(esPath), STR(error.localizedFailureReason));
                }
            }
            
            return esPath;
        }];
	
    _logFile = [[ProcFileReadWrite alloc]
        initWithDir:^NSString *{return @"/log";}
        fileName:@"line"
        readStr:^NSString* {return @"";}
        writeStr:^(NSString* str)
        {
            NSRange range = [str rangeOfString:@"\f"];
            if (range.location != NSNotFound)
            {
                NSString* text = [str substringFromIndex:range.location+1];
                text = [text replaceCharacters:@"\f" with:@"\\f"];
                LOG(STR([str substringToIndex:range.location]), "%s", STR(text));
            }
            else
                LOG("Error", "expected '<topic>\f<line>' not: '%s'", STR(str));
        }];
    
	_pasteBoardText = [[ProcFileReadWrite alloc]
        initWithDir:^NSString *{return @"/";}
        fileName:@"pasteboard-text"
        readStr:^NSString* {
            NSPasteboard* pb = [NSPasteboard generalPasteboard];
            NSString* str = [pb stringForType:NSStringPboardType];
            return str;
        }
        writeStr:^(NSString* str)
        {
            NSPasteboard* pb = [NSPasteboard generalPasteboard];
            [pb clearContents];
            [pb writeObjects:@[str]];
        }];
    
    _versionFile = [[ProcFileReader alloc]
        initWithDir:^NSString *{return @"/";}
        fileName:@"version"
        readStr:^NSString*
        {
            NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
            return [info objectForKey:@"CFBundleShortVersionString"];
        }];
    
    _copyItem = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/copy";}
        handler:^NSArray *(NSArray *args) {
            NSString* srcPath = args[0];
            NSString* dstPath = args[1];
            
            NSError* error = nil;
            if (([[NSFileManager defaultManager] copyItemAtPath:srcPath toPath:dstPath error:&error]))
            {
                return @[@"0", @""];
            }
            else
            {
                return @[[NSString stringWithFormat:@"%ld", (long)error.code], error.localizedFailureReason];
            }
        }];
    
    _deleteItem = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/delete";}
         handler:^NSArray *(NSArray *args) {
             NSString* path = args[0];
             
             NSError* error = nil;
             if ([[NSFileManager defaultManager] removeItemAtPath:path error:&error])
             {
                 return @[@"0", @""];
             }
             else
             {
                 return @[[NSString stringWithFormat:@"%ld", (long)error.code], error.localizedFailureReason];
             }
         }];

    _trashItem = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/trash";}
         handler:^NSArray *(NSArray *args) {
             NSString* path = args[0];
             
             NSError* error = nil;
             NSURL* url = [[NSURL alloc] initFileURLWithPath:path];
             if ([[NSFileManager defaultManager] trashItemAtURL:url resultingItemURL:nil error:&error])
             {
                 return @[@"0", @""];
             }
             else
             {
                 return @[[NSString stringWithFormat:@"%ld", (long)error.code], error.localizedFailureReason];
             }
         }];
    
    _showItem = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/show-in-finder";}
        handler:^NSArray *(NSArray *args) {
            NSString* path = args[0];
            
            NSError* error = nil;
            if ([[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""])
            {
                return @[@"0", @""];
            }
            else
            {
                return @[[NSString stringWithFormat:@"%ld", (long)error.code], error.localizedFailureReason];
            }
        }];
    
    _newDirectory = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/new-directory";}
        handler:^NSArray *(NSArray *args) {
            NSString* path = args[0];
            
            NSError* error = nil;
            if (([[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error]))
            {
                return @[@"0", @""];
            }
            else
            {
                return @[[NSString stringWithFormat:@"%ld", (long)error.code], error.localizedFailureReason];
            }
        }];

    _openAsBinary = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/open-as-binary";}
        handler:^NSArray *(NSArray *args) {
            NSString* path = args[0];
            
            dispatch_queue_t main = dispatch_get_main_queue();
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
            dispatch_after(delay, main, ^{
                NSURL* url = [[NSURL alloc] initFileURLWithPath:path];
                [self openBinary:url];
            });
            
            return @[@"0", @""];
        }];
    
    _openLocal = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/open-local";}
         handler:^NSArray *(NSArray *args) {
             NSString* path = args[0];
             
             dispatch_queue_t main = dispatch_get_main_queue();
             dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
             dispatch_after(delay, main, ^{
                 (void) openLocalPath(path);
             });
             
             return @[@"0", @""];
         }];
    
    _addMenuItem = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/add-menu-item";}
         handler:^NSArray *(NSArray *args) {
             NSString* location = args[0];
             NSString* title    = args[1];
             NSString* path     = args[2];
             
             if ([location isEqualToString:@"text view"] || [location isEqualToString:@"find"])
             {
                 static int next_id = 1;
                 NSString* ID = [NSString stringWithFormat:@"item %d", next_id++];
                 
                 dispatch_queue_t main = dispatch_get_main_queue();
                 dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
                 dispatch_after(delay, main, ^{
                     if ([location isEqualToString:@"text view"])
                         [self _addTextViewItem:ID title:title path:path];
                     else
                         [self _addFindItem:ID title:title path:path];
                 });
                 return @[ID];
             }
             else
             {
                 return @[@"1", @"bad location"];
             }
         }];
    
    _setMenuItemTitle = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/set-menu-item-title";}
        handler:^NSArray *(NSArray *args) {
            NSString* ID    = args[0];
            NSString* title = args[1];
            
            dispatch_queue_t main = dispatch_get_main_queue();
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
            dispatch_after(delay, main, ^{
                [self _setMenuItemTitle:ID title:title];
            });
            
            return @[@"0", @""];
        }];
    
    _disableMenuItem = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/disable-menu-item";}
        handler:^NSArray *(NSArray *args) {
            NSString* ID = args[0];
            
            dispatch_queue_t main = dispatch_get_main_queue();
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
            dispatch_after(delay, main, ^{
                [self _toggleMenuItem:ID enabled:false];
            });
            
            return @[@"0", @""];
        }];
    
    _enableMenuItem = [[ProcFileAction alloc] initWithDir:^NSString *{return @"/actions/enable-menu-item";}
        handler:^NSArray *(NSArray *args) {
            NSString* ID = args[0];
            
            dispatch_queue_t main = dispatch_get_main_queue();
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
            dispatch_after(delay, main, ^{
                [self _toggleMenuItem:ID enabled:true];
            });
            
            return @[@"0", @""];
        }];
	
    [_procFileSystem addWriter:_beepFile];
    [_procFileSystem addReader:_appSetting];
    [_procFileSystem addReader:_appSettings];
    [_procFileSystem addReader:_cachesPath];
    [_procFileSystem addReader:_installedFilesPath];
    [_procFileSystem addReader:_resourcesPath];
    [_procFileSystem addReader:_extensionSettingsPath];
    [_procFileSystem addWriter:_logFile];
    [_procFileSystem addWriter:_pasteBoardText];
    [_procFileSystem addReader:_versionFile];
    [_procFileSystem addReader:_copyItem];
    [_procFileSystem addReader:_deleteItem];
    [_procFileSystem addReader:_trashItem];
    [_procFileSystem addReader:_showItem];
    [_procFileSystem addReader:_newDirectory];
    [_procFileSystem addReader:_pasteBoardText];
    [_procFileSystem addReader:_openAsBinary];
    [_procFileSystem addReader:_openLocal];
    [_procFileSystem addReader:_addMenuItem];
    [_procFileSystem addReader:_setMenuItemTitle];
    [_procFileSystem addReader:_disableMenuItem];
	[_procFileSystem addReader:_enableMenuItem];

    [TextController startup];

	[SpecialKeys setup];
	[Extensions setup];
}
#endif

- (id<SettingsContext>)parent
{
    return nil;
}

- (Settings*)settings
{
    return _settings;
}

- (IBAction)showPlaceholder:(id)sender
{
    UNUSED(sender);
}

- (IBAction)transformPlaceholder:(id)sender
{
    UNUSED(sender);
}

#if OLD_EXTENSIONS
- (void) _addTextViewItem:(NSString*)ID title:(NSString*)title path:(NSString*)path
{
    NSMenu* menu = self.textMenu;
    if (menu)
    {
        NSInteger index = [menu indexOfItemWithTag:1];
        
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(_onSelectExtensionMenuItem:) keyEquivalent:@""];
        [item setRepresentedObject:path];
        [menu insertSortedItem:item atIndex:index+1];
        
        [_items setObject:item forKey:ID];
    }
}

- (void) _addFindItem:(NSString*)ID title:(NSString*)title path:(NSString*)path
{
    NSMenu* menu = self.searchMenu;
    if (menu)
    {
        NSInteger index = [menu indexOfItemWithTag:3];
        
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(_onSelectExtensionMenuItem:) keyEquivalent:@""];
        [item setRepresentedObject:path];
        [menu insertItem:item atIndex:index+1];
        
        [_items setObject:item forKey:ID];
    }
}

- (void) _onSelectExtensionMenuItem:(NSMenuItem*)sender
{
    // Note that extensions are not expected to actually read the path: the notification is just
    // there to poke the extension.
    NSString* path = sender.representedObject;
    [Extensions invokeBlocking:path];
}
#endif

- (void) _setMenuItemTitle:(NSString*)ID title:(NSString*)title
{
    NSMenuItem* item = [_items objectForKey:ID];
    if (item)
    {
        [item setTitle:title];
    }
    else
    {
        LOG("App", "Couldn't find a menu item with ID '%s'", STR(ID));
    }
}

- (void) _toggleMenuItem:(NSString*)ID enabled:(bool)enabled
{
    NSMenuItem* item = [_items objectForKey:ID];
    if (item)
    {
        [item setEnabled:enabled];
    }
    else
    {
        LOG("App", "Couldn't find a menu item with ID '%s'", STR(ID));
    }
}

#if OLD_EXTENSIONS
- (void)_mountFailed:(NSNotification*)notification
{
	[SpecialKeys setup];	// needs the proc file system so we do it here
	
	NSDictionary* userInfo = [notification userInfo];
	NSString* path = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
	NSError* error = [userInfo objectForKey:kGMUserFileSystemErrorKey];
	LOG("Error", "failed to mount %s: %s", STR(path), STR(error.localizedFailureReason));
  
    _mounted = true;
    if (_launched)
        [self _postInit];
}
#endif

- (void)_postInit
{
    __weak AppDelegate* this = self;
    [TranscriptController startedUp];
    [[NSApp helpMenu] setDelegate:this];
    
    [self _installFiles];
    [self _loadSettings];
    [self _loadHelpFiles];
    [self _updateDirectoriesMenu];
    [self _watchInstalledFiles];
    [TranscriptController writeInfo:@""];   // make sure we create this within the main thread
#if OLD_EXTENSIONS
    [StartupScripts setup];
#endif
    [WindowsDatabase setup];
    [Languages setup];
    [ExtensionListener setup];
    
    [self _addTransformItems];
    
#if OLD_EXTENSIONS
    if (_mountPath)
        [self _handleMount];
#endif
    
    [Plugins startup];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	UNUSED(notification);
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{@"recent-directories": @[]}];
	
    _launched = true;
    
#if OLD_EXTENSIONS
    if (_mounted)
#endif
        [self _postInit];
}

// Note that windows will still be open when this is called.
- (void)applicationWillTerminate:(NSNotification *)notification
{
	UNUSED(notification);
	LOG("App", "Terminating");
	
#if OLD_EXTENSIONS
	[_procFileSystem teardown];
#endif
    [Plugins teardown];
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

+ (void)execute:(NSString*)name afterDelay:(NSTimeInterval)delay withBlock:(NullaryBlock)block
{
    AppDelegate* delegate = (AppDelegate*) [NSApp delegate];
    
    if (!delegate->_pendingBlocks[name])
    {
        delegate->_pendingBlocks[name] = block;
        [delegate performSelector:@selector(_executeSelector:) withObject:name afterDelay:delay];
    }
}

+ (void)execute:(NSString*)name withSelector:(SEL)selector withObject:(id) object afterDelay:(NSTimeInterval)delay
{
    NullaryBlock block = ^()
        {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            
            id result = [object performSelector:selector];
            UNUSED(result);
            //ASSERT(result == nil);        // getting garbage(?) NSNumber results when calling void methods with 10.11
            
            #pragma clang diagnostic pop
        };
    [AppDelegate execute:name afterDelay:delay withBlock:block];
}

+ (void)execute:(NSString*)name withSelector:(SEL)selector withObject:(id) object deferBy:(NSTimeInterval)delay
{
    AppDelegate* delegate = (AppDelegate*) [NSApp delegate];
    
    NullaryBlock block = delegate->_pendingBlocks[name];
    if (block)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:delegate selector:@selector(_executeSelector:) object:name];
        [delegate->_pendingBlocks removeObjectForKey:name];
    }
    
    [AppDelegate execute:name withSelector:selector withObject:object afterDelay:delay];
}

+ (void)execute:(NSString*)name deferBy:(NSTimeInterval)delay withBlock:(NullaryBlock)block
{
    AppDelegate* delegate = (AppDelegate*) [NSApp delegate];
    
    NullaryBlock oldBlock = delegate->_pendingBlocks[name];
    if (oldBlock)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:delegate selector:@selector(_executeSelector:) object:name];
        [delegate->_pendingBlocks removeObjectForKey:name];
    }
    
    [AppDelegate execute:name afterDelay:delay withBlock:block];
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

- (NSUInteger)_findDirectoryWindow:(NSString*)path
{
    for (NSUInteger i = 0; i < _recentDirectories.count; ++i)
    {
        NSArray* elements = _recentDirectories[i];
        NSString* candidate = elements[1];
        if ([path compare:candidate] == NSOrderedSame)
            return i;
    }
    
    return NSUIntegerMax;
}

- (void)newMainWindow:(NSNotification*)notification
{
    NSWindow* window = notification.object;
    if ([window.windowController isKindOfClass:[DirectoryController class]])
    {
        DirectoryController* controller = window.windowController;
        NSArray* elements = @[[NSDate date], controller.path];
        
        NSUInteger index = [self _findDirectoryWindow:controller.path];
        if (index < _recentDirectories.count)
            [_recentDirectories removeObjectAtIndex:(NSUInteger)index];
        [_recentDirectories insertObject:elements atIndex:0];
        
        // maximumRecentDocumentCount can change at any time so we'll always do this.
        while (_recentDirectories.count > [[NSDocumentController sharedDocumentController] maximumRecentDocumentCount])
            [_recentDirectories removeLastObject];
        
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:_recentDirectories forKey:@"recent-directories"];
        
        if (_launched)
            [self _updateDirectoriesMenu];
    }
}

- (void)settingsChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
	[SearchSite updateMainMenu:self.searchMenu];
    [BuildErrors.instance appSettingsChanged];
	
	NSMutableArray* helps = [NSMutableArray new];
	[activeContext.settings enumerate:@"ContextHelp" with:
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

- (void)openRecentDir:(id)sender
{
	NSString* path = [sender representedObject];
    [DirectoryController open:path];
}

- (bool)_directoryWindowHasDupes:(NSString*)path
{
    int count = 0;
    
    for (NSUInteger i = 0; i < _recentDirectories.count && count < 2; ++i)
    {
        NSArray* elements = _recentDirectories[i];
        NSString* candidate = elements[1];
        if ([path compare:candidate] == NSOrderedSame)
            ++count;
    }
    
    return count == 2;
}

- (void)_updateDirectoriesMenu
{
    [self.recentDirectoriesMenu removeAllItems];
    
    for (NSArray* elements in _recentDirectories)
    {
        if (elements.count == 2)
        {
            NSString* path = elements[1];
            NSString* title = [self _directoryWindowHasDupes:path] ? path.reversePath : path.lastPathComponent;

            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openRecentDir:) keyEquivalent:@""];
            [item setRepresentedObject:path];
            [self.recentDirectoriesMenu addItem:item];
        }
    }
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

#if OLD_EXTENSIONS
- (void)runFTests:(id)sender
{
	UNUSED(sender);
	runFunctionalTests();
}
#endif

// This isn't terribly useful with auto-saving on, but it will help make old-school
// uses more comfortable. There's also a save all method on NSDocumentController but
// I think it just auto-saves because it doesn't clear the "edited" text within the
// window titles.
- (void)saveAllDocuments:(id)sender
{
	for (NSDocument* doc in [[NSDocumentController sharedDocumentController] documents])
	{
		if (doc.isDocumentEdited)
			if (doc.fileURL && doc.fileType)
				[doc saveDocument:sender];
	}
}

#if OLD_EXTENSIONS
- (void)runFTest:(id)sender
{
	runFunctionalTest([sender representedObject]);
}
#endif

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

- (void)nextBuildError:(id)sender
{
    UNUSED(sender);
    [BuildErrors.instance gotoNextError];
}

- (void)previousBuildError:(id)sender
{
    UNUSED(sender);
    [BuildErrors.instance gotoPreviousError];
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
	if (button == NSModalResponseOK)
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
	
	if (button == NSModalResponseOK)
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
    else if (sel == @selector(openRecentDir:))
    {
        // Directory could be on a remote file system that isn't mounted or on a removable drive.
        NSString* path = item.representedObject;
        enabled = [[NSFileManager defaultManager] fileExistsAtPath:path];
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
    else if (sel == @selector(nextBuildError:))
    {
        enabled = [BuildErrors.instance canGotoNextError];
    }
    else if (sel == @selector(previousBuildError:))
    {
        enabled = [BuildErrors.instance canGotoPreviousError];
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
#if OLD_EXTENSIONS
    else if (sel == @selector(_onSelectExtensionMenuItem:))
    {
        enabled = item.enabled;
    }
#endif
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
		[installer addSourceItem:@"extensions"];
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
    _settings = [[Settings alloc] init:@"app.mimsy" context:self];
	
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

	dir = [Paths installedDir:@"extensions"];
	_extensionsWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		  ^(NSString* path, FSEventStreamEventFlags flags)
		  {
			  UNUSED(path, flags);
#if OLD_EXTENSIONS
			  [Extensions setup];
#endif
			  [[NSNotificationCenter defaultCenter] postNotificationName:@"ExtensionsChanged" object:self];
		  }
		  ];
	
#if OLD_EXTENSIONS
	dir = [Paths installedDir:@"scripts/startup"];
	_scriptsStartupWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		  ^(NSString* path, FSEventStreamEventFlags flags)
		  {
			  UNUSED(path, flags);
			  [StartupScripts setup];
			  [[NSNotificationCenter defaultCenter] postNotificationName:@"StartupScriptsChanged" object:self];
		  }
		  ];
#endif
    
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
	
#if OLD_EXTENSIONS
    _keyStoreFile = [self _createKeyStore:@"key-values"];
#endif
    
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

#if OLD_EXTENSIONS
- (ProcFileKeyStoreRW*)_createKeyStore:(NSString*)name
{
    ProcFileKeyStoreRW* file = nil;
    
    ProcFileSystem* fs = self.procFileSystem;
    if (fs)
    {
        file = [[ProcFileKeyStoreRW alloc] initWithDir:^NSString*
            {
                return [NSString stringWithFormat:@"/%@", name];
            }];
        [fs addWriter:file];
    }
    
    return file;
}
#endif

@end
