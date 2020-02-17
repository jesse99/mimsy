#import "AppDelegate.h"

#include <dirent.h>
#include <sys/stat.h>

#import "ColorCategory.h"
#import "ConfigParser.h"
#import "Constants.h"
#import "DirectoryController.h"
#import "DirectoryWatcher.h"
#import "FindInFilesController.h"
#import "FindResultsController.h"
#import "Glob.h"
#import "HelpItem.h"
#import "InstallFiles.h"
#import "Language.h"
#import "Languages.h"
#import "Logger.h"
#import "MenuCategory.h"
#import "OpenFile.h"
#import "OpenSelection.h"
#import "Paths.h"
#import "Plugins.h"
#import "SearchSite.h"
#import "SelectStyleController.h"
#import "SpecialKeys.h"
#import "TextController.h"
#import "TimeMachine.h"
#import "TranscriptController.h"
#import "Utils.h"
#import "WindowsDatabase.h"
#import "Mimsy-Swift.h"

typedef BOOL (^MenuEnabledBlock)(NSMenuItem* _Nonnull);
typedef void (^MenuInvokeBlock)(void);
typedef void (^TextViewBlock)(id<MimsyTextView> _Nonnull);
typedef BOOL (^TextViewKeyBlock)(id<MimsyTextView> _Nonnull);
typedef void (^ProjectBlock)(id<MimsyProject> _Nonnull);

@implementation ProjectContextItem

@end

// ------------------------------------------------------------------------------------
// We need this lame class because:
// 1) If we just call saveDocument on all the documents then, when we build remotely,
// the documents are still saving when the build starts (even if we put a big sleep
// after the saves).
// 2) NSDocument is still old school and relies on delegates and selectors to provide
// save status instead of using blocks which would allow us to more nicely encapsulate
// state..
@interface SaveAllDocuments : NSObject

- (id)init:(BoolBlock)saved;

- (void)save:(NSDocument*)doc;

- (void)finishedSaving;

- (void)document:(NSDocument*)document didSave:(BOOL)suceeded contextInfo:(void*)info;

@end

@implementation SaveAllDocuments
{
    BoolBlock _callback;
    bool _success;
    int _count;
}

- (id)init:(BoolBlock)saved
{
    self = [super init];
    
    if (self)
    {
        _callback = saved;
        _success = true;
        _count = 0;
    }
    
    return self;
}

- (void)save:(NSDocument*)doc
{
    ++_count;
    [doc saveDocumentWithDelegate:self didSaveSelector:@selector(document:didSave:contextInfo:) contextInfo:NULL];
}

- (void)finishedSaving
{
    if (_count == 0)            // i.e. we didn't actually save anything
        _callback(_success);
}

- (void)document:(NSDocument*)document didSave:(BOOL)suceeded contextInfo:(void*)info
{
    UNUSED(document, info);
    
    if (!suceeded)
        _success = false;
    
    if (--_count == 0)
        _callback(_success);
}

@end

// ------------------------------------------------------------------------------------
@interface PluginMenuItem : NSObject

- (id)initFromEnabled:(MenuEnabledBlock)enabled invoke:(MenuInvokeBlock)invoke;

@property (readonly) MenuEnabledBlock enabled;
@property (readonly) MenuInvokeBlock invoke;

@end

@implementation PluginMenuItem

- (id)initFromEnabled:(MenuEnabledBlock)enabled invoke:(MenuInvokeBlock)invoke
{
    self = [super init];
    
    if (self)
    {
        _enabled = enabled;
        _invoke = invoke;
    }
    
    return self;
}

@end

// ------------------------------------------------------------------------------------
@interface TextKeyItem : NSObject

- (id)init:(NSString*)identifier invoke:(TextViewKeyBlock)invoke;

@property (readonly) NSString* identifier;
@property (readonly) TextViewKeyBlock invoke;

@end

@implementation TextKeyItem

- (id)init:(NSString*)identifier invoke:(TextViewKeyBlock)invoke
{
    self = [super init];
    
    if (self)
    {
        _identifier = identifier;
        _invoke = invoke;
    }
    
    return self;
}

@end

// ------------------------------------------------------------------------------------
void initLogGlobs()
{
	MimsyPath* path = [Paths installedDir:@"settings"];
	path = [path appendWithComponent:@"logging.mimsy"];
	
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

// ------------------------------------------------------------------------------------
@implementation AppDelegate
{
	DirectoryWatcher* _languagesWatcher;
    DirectoryWatcher* _settingsWatcher;
	DirectoryWatcher* _stylesWatcher;
	DirectoryWatcher* _helpWatcher;
    NSMutableDictionary* _projectHooks;
    NSMutableDictionary* _textHooks;
    NSMutableDictionary* _textKeyHooks;
    
	NSMutableDictionary* _pendingBlocks;
	NSArray* _helpFileItems;
	NSArray* _helpSettingsItems;
    NSMutableArray* _recentDirectories; // array [timestamp, path]
    NSMutableDictionary* _noSelectionItems;
    NSMutableDictionary* _withSelectionItems;
    NSMutableArray* _projectItems;
    NSMutableDictionary* _applyElementStyles;
    
    bool _mounted;
    NSString* _mountPath;
    bool _launched;
    NSMutableDictionary* _items;
    Settings* _layeredSettings;
    
    InstallFiles* _installer;
    id<SettingsContext> _parent;
}

- (id)init
{
	self = [super init];
	
	if (self)
	{
//		ASSERT([NSThread isMultiThreaded]);
		
        _layeredSettings = [[Settings alloc] init:@"app.mimsy" context:self];
		_pendingBlocks = [NSMutableDictionary new];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newMainWindow:) name:NSWindowDidBecomeMainNotification object:nil];
		
        _items = [NSMutableDictionary new];
        _projectHooks = [NSMutableDictionary new];
        _textHooks = [NSMutableDictionary new];
        _textKeyHooks = [NSMutableDictionary new];
        _noSelectionItems = [NSMutableDictionary new];
        _withSelectionItems = [NSMutableDictionary new];
        _projectItems = [NSMutableArray new];
        _applyElementStyles = [NSMutableDictionary new];
        
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        _recentDirectories = [NSMutableArray new];
        [_recentDirectories addObjectsFromArray:[defaults arrayForKey:@"recent-directories"]];

        _inited = true;
	}
	
	return self;
}

- (void)logString:(NSString*)topic text:(NSString*)text
{
    LOG(STR(topic), "%s", STR(text));
}


// Presumbably this is faster than attributesOfItemAtPath:error: because that method returns a bunch
// more stuff (which adds up quick when using stuff like remote samba volumes).
- (NSNumber* __nullable)_modTime:(MimsyPath* __nonnull)path error:(NSError* __nullable*)error
{
    struct stat state;
    int err = stat(path.asString.UTF8String, &state);
    if (!err)
    {
        double secs = state.st_mtimespec.tv_sec + 1.0e-9*state.st_mtimespec.tv_nsec;
        return [NSNumber numberWithDouble:secs];
    }
    else
    {
        if (error)
        {
            NSString* mesg = [NSString stringWithFormat:@"Failed to stat '%@': %s", path, strerror(errno)];
            NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
            *error = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
        }
        return nil;
    }
}

- (NSArray<id<MimsyLanguage>>* __nonnull)languages
{
    return [Languages languages];
}

- (id<MimsyLanguage> __nullable)findLanguage:(MimsyPath* __nonnull)path
{
    __block Language* language = nil;
    
    [Languages enumerate:^(Language *candidate, bool *stop)
    {
        if ([candidate matches:path])
        {
            language = candidate;
            *stop = true;
        }
    }];
    
    return language;
}

-(BOOL)addNewMenuItem:(NSMenuItem*)item loc:(enum MenuItemLoc)loc sel:(NSString*)sel enabled:(MenuEnabledBlock)enabled invoke:(__attribute__((noescape)) MenuInvokeBlock)invoke
{
    NSMenu* menu = nil;
    NSInteger at = 0;
    
    SEL selector = NSSelectorFromString(sel);
    if (!selector)
        LOG("Error", "Couldn't find a selector for %s", STR(sel));
    
    if (selector && [self _findSelector:selector menu:&menu at:&at])
    {
        if (loc == MenuItemLocBefore)
            [menu insertItem:item atIndex:at];
        
        else if (loc == MenuItemLocAfter)
            [menu insertItem:item atIndex:at+1];
        
        else if (loc == MenuItemLocSorted)
            [menu insertSortedItem:item atIndex:at];
        
        PluginMenuItem* pi = [[PluginMenuItem alloc] initFromEnabled:enabled invoke:invoke];
        [item setRepresentedObject:pi];
        
        [item setTarget:self];
        [item setAction:@selector(_invokePluginMenuItem:)];
    }
    
    return false;
}

- (NSDictionary<NSString*, NSString*>* __nonnull)environment
{
    NSMutableDictionary* env = [NSMutableDictionary new];
    [env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
    
    NSArray* newPaths = [self.layeredSettings stringValues:@"PrependPath"];
    if (newPaths && newPaths.count > 0)
    {
        NSString* prefix = [newPaths componentsJoinedByString:@":"];
        
        NSString* paths = env[@"PATH"];
        if (paths && paths.length > 0)
            paths = [NSString stringWithFormat:@"%@:%@", prefix, paths];
        else
            paths = prefix;
        
        env[@"PATH"] = paths;
    }
    
    newPaths = [self.layeredSettings stringValues:@"AppendPath"];
    if (newPaths && newPaths.count > 0)
    {
        NSString* suffix = [newPaths componentsJoinedByString:@":"];
        
        NSString* paths = env[@"PATH"];
        if (paths && paths.length > 0)
            paths = [NSString stringWithFormat:@"%@:%@", paths, suffix];
        else
            paths = suffix;
        
        env[@"PATH"] = paths;
    }
    
    return env;
}

- (void)installSettingsPath:(MimsyPath* _Nonnull)path
{
    [_installer addSourcePath:path];
}

- (id<MimsySettings> __nonnull)settings 
{
    return _layeredSettings;
}

- (void)enumerateWithDir:(MimsyPath* __nonnull)root recursive:(BOOL)recursive error:(__attribute__((noescape)) void (^ __nonnull)(NSString* __nonnull))error predicate:(__attribute__((noescape)) BOOL (^)(MimsyPath* __nonnull, NSString* __nonnull))predicate callback:(__attribute__((noescape)) void (^ __nonnull)(MimsyPath* __nonnull, NSArray<NSString*>* __nonnull))callback
{
    NSMutableArray<MimsyPath*>* dirs = [NSMutableArray new];
    [dirs addObject:root];
    
    NSMutableArray<NSString*>* fileNames = [NSMutableArray new];
    while (dirs.count > 0)
    {
        MimsyPath* dir = [dirs lastObject];
        [dirs removeLastObject];
        
        DIR* dirP = opendir(dir.asString.UTF8String);
        if (!dirP)
        {
            NSString* mesg = [[NSString alloc] initWithFormat:@"Failed to open '%@': %s.", dir, strerror(errno)];
            error(mesg);
            continue;
        }
        
        struct dirent entry;
        struct dirent* entryP;
        [fileNames removeAllObjects];
        while (true)
        {
            int err = readdir_r(dirP, &entry, &entryP);
            if (err)
            {
                NSString* mesg = [[NSString alloc] initWithFormat:@"Failed to read '%@': %s.", dir, strerror(errno)];
                error(mesg);
                break;
            }
            else if (!entryP)
            {
                break;
            }
            
            if (entry.d_name[0] != '.')
            {
                if (entry.d_type == DT_REG)
                {
                    NSString* fileName = [[NSString alloc] initWithBytes:entry.d_name length:entry.d_namlen encoding:NSUTF8StringEncoding];
                    if (!predicate || predicate(dir, fileName))
                        [fileNames addObject:fileName];
                }
                else if (recursive && entry.d_type == DT_DIR)
                {
                    NSString* fileName = [[NSString alloc] initWithBytes:entry.d_name length:entry.d_namlen encoding:NSUTF8StringEncoding];
                    MimsyPath* path = [dir appendWithComponent:fileName];
                    [dirs addObject:path];
                }
            }
        }

        // Batching the files up should be faster because w'll get better locality reading the directory
        // contents before dealing with files. Probably won't make much difference for local volumes but
        // remote volumes can be quite slow.
        callback(dir, fileNames);
        (void) closedir(dirP);
    }
}

- (void)addKeyHelp:(NSString * __nonnull)plugin :(NSString * __nonnull)context :(NSString * __nonnull)key :(NSString * __nonnull)description
{
    if ([plugin contains:@"."])
    {
        NSArray* parts = [plugin componentsSeparatedByString:@"."];
        plugin = parts[parts.count - 1];
    }
    
    [SpecialKeys addPlugin:plugin context:context key:key description:description];
}

- (void)removeKeyHelp:(NSString * __nonnull)plugin :(NSString * __nonnull)context
{
    [SpecialKeys removePlugin:plugin context:context];
}

- (void)registerTextViewKey:(NSString* __nonnull)key :(NSString* __nonnull)identifier :(TextViewKeyBlock)hook
{
    key = [key lowercaseString];
    NSMutableArray* items = [_textKeyHooks objectForKey:key];
    if (!items)
    {
        items = [NSMutableArray new];
        _textKeyHooks[key] = items;
    }
    
    TextKeyItem* item = [[TextKeyItem alloc] init:identifier invoke:hook];
    [items addObject:item];
}


- (void)clearRegisterTextViewKey:(NSString* __nonnull)identifier
{
    for (NSString* key in _textKeyHooks)
    {
        NSMutableArray* items = _textKeyHooks[key];
        
        NSUInteger i = 0;
        while (i < items.count)
        {
            TextKeyItem* candidate = items[i];
            if ([candidate.identifier isEqualToString:identifier])
                [items removeObjectAtIndex:i];
            else
                ++i;
        }
    }
}

- (bool)invokeTextViewKeyHook:(NSString* _Nonnull)key view:(id<MimsyTextView> _Nonnull)view
{
    bool handled = false;

    NSMutableArray* items = [_textKeyHooks objectForKey:key];
    for (TextKeyItem* item in items)
    {
        handled = item.invoke(view);
        if (handled)
            break;
    }
    
    return handled;
}

- (void)registerProjectContextMenu:(ProjectContextMenuItemTitleBlock)title invoke:(InvokeProjectCommandBlock)invoke
{
    ProjectContextItem* item = [ProjectContextItem new];
    item.title = title;
    item.invoke = invoke;
    
    [_projectItems addObject:item];
}

- (NSArray* _Nullable)projectItems
{
    return _projectItems;
}

- (NSDictionary* _Nonnull)applyElementHooks
{
    return _applyElementStyles;
}

- (void)registerApplyStyle:(NSString*)element :(__attribute__((noescape)) TextRangeBlock)hook
{
    element = [element lowercaseString];
    NSMutableArray* items = [_applyElementStyles objectForKey:element];
    if (!items)
    {
        items = [NSMutableArray new];
        _applyElementStyles[element] = items;
    }
    
    [items addObject:hook];
}

- (void)registerNoSelectionTextContextMenu:(enum NoTextSelectionPos)pos callback:(__attribute__((noescape)) TextContextMenuBlock)callback
{
    NSValue* key = @((int) pos);
    NSMutableArray* items = [_noSelectionItems objectForKey:key];
    if (!items)
    {
        items = [NSMutableArray new];
        _noSelectionItems[key] = items;
    }
    
    [items addObject:callback];
}

- (void)registerWithSelectionTextContextMenu:(enum WithTextSelectionPos)pos callback:(__attribute__((noescape)) TextContextMenuBlock)callback
{
    NSValue* key = @((int) pos);
    NSMutableArray* items = [_withSelectionItems objectForKey:key];
    if (!items)
    {
        items = [NSMutableArray new];
        _withSelectionItems[key] = items;
    }
    
    [items addObject:callback];
}

- (NSArray<TextContextMenuBlock>* _Nullable)noSelectionItems:(enum NoTextSelectionPos)pos
{
    NSValue* key = @((int) pos);
    return [_noSelectionItems objectForKey:key];
}

- (NSArray<TextContextMenuBlock>* _Nullable)withSelectionItems:(enum WithTextSelectionPos)pos
{
    NSValue* key = @((int) pos);
    return [_withSelectionItems objectForKey:key];
}

- (id<MimsyTranscript>)transcript
{
    return [TranscriptController getInstance];
}

- (id<MimsyTextView>)textView
{
    for (NSWindow* window in [NSApp orderedWindows])
    {
        if (window.isVisible && !window.isMiniaturized)
            if (window.windowController && [window.windowController isKindOfClass:[TextController class]])
                return window.windowController;
            else
                return nil;
    }
    return nil;
}

- (id<MimsyGlob> __nonnull)globWithString:(NSString* __nonnull)glob
{
    return [[Glob alloc] initWithGlob:glob];
}

- (id<MimsyGlob> __nonnull)globWithStrings:(NSArray<NSString*>* __nonnull)globs
{
    return [[Glob alloc] initWithGlobs:globs];
}

- (void)open:(MimsyPath* _Nonnull)path
{
    [OpenFile openPath:path atLine:-1 atCol:-1 withTabWidth:-1];
}

- (void)open:(MimsyPath* __nonnull)path withRange:(NSRange)range
{
    [OpenFile openPath:path withRange:range];
}

- (void)openAsBinary:(MimsyPath* _Nonnull)path
{
    NSURL* url = path.asURL;
    [self openBinary:url];
}

- (NSColor*)mimsyColor:(NSString*)name
{
    return [NSColor colorWithMimsyName:name];
}

- (void)registerProject:(enum ProjectNotification)kind :(__attribute__((noescape)) ProjectBlock)hook
{
    NSValue* key = @((int) kind);
    NSMutableArray* hooks = [_projectHooks objectForKey:key];
    if (!hooks)
    {
        hooks = [NSMutableArray new];
        _projectHooks[key] = hooks;
    }
    
    [hooks addObject:hook];
}

- (void)invokeProjectHook:(enum ProjectNotification)kind project:(id<MimsyProject> _Nonnull)project
{
    NSValue* key = @((int) kind);
    NSMutableArray* hooks = [_projectHooks objectForKey:key];
    for (ProjectBlock hook in hooks)
    {
        hook(project);
    }
}

- (void)registerTextView:(enum TextViewNotification)kind :(__attribute__((noescape)) TextViewBlock)hook
{
    NSValue* key = @((int) kind);
    NSMutableArray* hooks = [_textHooks objectForKey:key];
    if (!hooks)
    {
        hooks = [NSMutableArray new];
        _textHooks[key] = hooks;
    }
    
    [hooks addObject:hook];
}

- (void)invokeTextViewHook:(enum TextViewNotification)kind view:(id<MimsyTextView> _Nonnull)view
{
    NSValue* key = @((int) kind);
    NSMutableArray* hooks = [_textHooks objectForKey:key];
    for (TextViewBlock hook in hooks)
    {
        hook(view);
    }
}

-(void)_invokePluginMenuItem:(NSMenuItem*)item
{
    PluginMenuItem* pi = [item representedObject];
    (pi.invoke)();
}

-(bool)_findSelector:(SEL)sel menu:(NSMenu**)menu at:(NSInteger*)at
{
    NSMutableArray* menus = [NSMutableArray new];
    [menus addObject:[NSApp mainMenu]];
    
    while (menus.count > 0)
    {
        NSMenu* candidate = [menus objectAtIndex:0];
        [menus removeObjectAtIndex:0];
        
        for (NSInteger i = 0; i < candidate.numberOfItems; ++i)
        {
            NSMenuItem* item = [candidate itemAtIndex:i];
            if (item.hasSubmenu)
            {
                [menus addObject:item.submenu];
            }
            else
            {
                if (item.action == sel)
                {
                    *menu = candidate;
                    *at = i;
                    return true;
                }
            }
        }
    }
    
    return false;
}

- (void)setSettingsParent:(id<SettingsContext> _Nullable)parent
{
    _parent = parent;
}

- (id<SettingsContext>)parent
{
    return _parent;
}

- (Settings*)layeredSettings
{
    return _layeredSettings;
}

// Selector attached to a hidden menu item giving plugins a place to add menu items to.
- (IBAction)showItems:(id)sender
{
    UNUSED(sender);
}

// Selector attached to a hidden menu item giving plugins a place to add menu items to.
- (IBAction)transformItems:(id)sender
{
    UNUSED(sender);
}

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

- (void)_postInit
{
    __weak AppDelegate* this = self;
    [TranscriptController startedUp];
    [[NSApp helpMenu] setDelegate:this];
    activeContext = self;
    
    _installer = [self _createInstaller];
    [Plugins startLoading];
    [Plugins installFiles:_installer];
    [_installer install];
    _installer = nil;

    [self _loadSettings];
    [self _loadHelpFiles];
    [self _updateDirectoriesMenu];
    [self _watchInstalledFiles];
    [TranscriptController writeInfo:@""];   // make sure we create this within the main thread
    [SpecialKeys setup];
    [WindowsDatabase setup];
    [Languages setup];
    
    [Plugins finishLoading];
    [SpecialKeys updated];
    
    // Previously opened windows are opened by Cocoa very early during startup
    // (before the AppDelegate finishes initializing and even before things
    // like the main menu are set up). So it is much easier to defer notifications
    // of opened windows until after everything is initialized.
    [DirectoryController enumerate:^(DirectoryController* _Nonnull p) {[self invokeProjectHook:ProjectNotificationOpened project:p];}];
    
    [TextController enumerate:^(TextController* c, bool* stop) {
        UNUSED(stop);
        [self invokeTextViewHook:TextViewNotificationOpened view:c];
    }];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	UNUSED(notification);
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{@"recent-directories": @[]}];
	
    _launched = true;
    [self _postInit];
}

// Note that windows will still be open when this is called.
- (void)applicationWillTerminate:(NSNotification *)notification
{
	UNUSED(notification);
	LOG("App", "Terminating");
	
    [Plugins teardown];
}

- (void)_executeSelector:(NSString*)name
{
	NullaryBlock block = self->_pendingBlocks[name];
	@try
	{
        if (block)
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

- (NSUInteger)_findDirectoryWindow:(MimsyPath*)path
{
    for (NSUInteger i = 0; i < _recentDirectories.count; ++i)
    {
        NSArray* elements = _recentDirectories[i];
        NSString* candidate = elements[1];
        if ([path.asString compare:candidate] == NSOrderedSame)
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
        NSArray* elements = @[[NSDate date], controller.path.asString];
        
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
	[activeContext.layeredSettings enumerate:@"ContextHelp" with:
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
        MimsyPath* path = [[MimsyPath alloc] initWithString:@":restoring:"];
		NSWindowController* controller = [DirectoryController open:path];
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
	NSString* object = [sender representedObject];
    MimsyPath* path = [[MimsyPath alloc] initWithString:object];
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

// This isn't too useful for people when auto-saving is on but it is useful when
// doing stuff like builds where we want more control over when documents are
// saved.
- (void)saveAllDocuments:(id)sender
{
	for (NSDocument* doc in [[NSDocumentController sharedDocumentController] documents])
	{
		if (doc.isDocumentEdited)
			if (doc.fileURL && doc.fileType)
				[doc saveDocument:sender];
	}
}

- (void)saveAllDocumentsWithBlock:(BoolBlock)saved
{
    SaveAllDocuments* saver = [[SaveAllDocuments alloc] init:saved];
    
    for (NSDocument* doc in [[NSDocumentController sharedDocumentController] documents])
    {
        if (doc.isDocumentEdited)
            if (doc.fileURL && doc.fileType)
                [saver save:doc];
    }
    
    [saver finishedSaving];
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
	
	MimsyPath* path = [Paths installedDir:nil];
	[[NSWorkspace sharedWorkspace] openFile:path.asString];
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
            MimsyPath* path = [[MimsyPath alloc] initWithString:url.path];
			(void) [DirectoryController open:path];
		}
	}	
}

- (IBAction)openAsBinaryAction:(id)sender
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
    else if (sel == @selector(_invokePluginMenuItem:))
    {
        PluginMenuItem* pi = [item representedObject];
        if (pi.enabled)
        {
            enabled = (pi.enabled)(item);
        }
        else
        {
            enabled = true;
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


- (InstallFiles*)_createInstaller
{
    InstallFiles* installer = nil;

    NSFileManager* fm = [NSFileManager defaultManager];
	NSArray* urls = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
	if (urls.count > 0)
	{
		MimsyPath* path = [[MimsyPath alloc] initWithString:[urls[0] path]];
		path = [path appendWithComponent:@"Mimsy"];
		
		installer = [[InstallFiles alloc] initWithDstPath:path];
		[installer addSourceFile:@"builders"];
		[installer addSourceFile:@"help"];
		[installer addSourceFile:@"languages"];
		[installer addSourceFile:@"settings"];
		[installer addSourceFile:@"styles"];
	}
	else
	{
		NSString* mesg = @"Failed to install support files: URLsForDirectory:NSApplicationSupportDirectory failed to find any directories.";
		[TranscriptController writeError:mesg];
	}
    
    return installer;
}

- (void)_loadHelpFiles
{
	MimsyPath* helpDir = [Paths installedDir:@"help"];
	Glob* glob = [[Glob alloc] initWithGlob:@"*-*.*"];
	
	NSError* error = nil;
	NSMutableArray* items = [NSMutableArray new];
	[Utils enumerateDir:helpDir glob:glob error:&error block:
		 ^(MimsyPath* path)
		 {
             if (![path.lastComponent contains:@".old"])
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
    _layeredSettings = [[Settings alloc] init:@"app.mimsy" context:self];
	
	MimsyPath* path = [Paths installedDir:@"settings"];
	path = [path appendWithComponent:@"app.mimsy"];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path.asString])
	{
		NSError* error = nil;
		ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
		if (parser)
		{
			[parser enumerate:
				 ^(ConfigParserEntry* entry)
				 {
                     [self->_layeredSettings addKey:entry.key value:entry.value];
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
	MimsyPath* dir = [Paths installedDir:@"languages"];
	_languagesWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(MimsyPath* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			[Languages languagesChanged];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"LanguagesChanged" object:self];
		}
	];

	dir = [Paths installedDir:@"settings"];
	_settingsWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(MimsyPath* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			initLogGlobs();
			[self _loadSettings];
            [Plugins refreshSettings];
            [SpecialKeys updated];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsChanged" object:self];
		}
		];
	
	dir = [Paths installedDir:@"help"];
	_helpWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		^(MimsyPath* path, FSEventStreamEventFlags flags)
		{
			UNUSED(path, flags);
			[self _loadHelpFiles];
		}
	];
    
    dir = [Paths installedDir:@"styles"];
	_stylesWatcher = [[DirectoryWatcher alloc] initWithPath:dir latency:1.0 block:
		  ^(MimsyPath* path, FSEventStreamEventFlags flags)
		  {
			  UNUSED(path, flags);
			  [[NSNotificationCenter defaultCenter] postNotificationName:@"StylesChanged" object:self];
		  }
		  ];
}

@end
