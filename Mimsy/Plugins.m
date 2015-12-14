#import "Plugins.h"

#import "AppDelegate.h"
#import "ConfigParser.h"
#import "Glob.h"
#import "InstallFiles.h"
#import "MimsyPlugins.h"
#import "Paths.h"
#import "Utils.h"

#include <objc/runtime.h>

// ------------------------------------------------------------------------------------
@interface PluginData : NSObject<SettingsContext>

- (id)init:(MimsyPlugin*)plugin;

@property (readonly) MimsyPlugin* plugin;
@property (readonly) NSMutableArray* settingNames; // file names for settings
@property NSUInteger checksum;

- (NSString*)bundleName;

- (void)swapInSettings:(Settings*)settings;
- (void)swapOutSettings;

@end

@implementation PluginData
{
    Settings* _settings;
}

- (id)init:(MimsyPlugin*)plugin
{
    self = [super init];
    
    if (self)
    {
        _plugin = plugin;
        _settingNames = [NSMutableArray new];
    }
    
    return self;
}

- (NSString*)bundleName
{
    return _plugin.bundle.bundlePath.lastPathComponent;
}

- (void)swapInSettings:(Settings*)settings
{
    _settings = settings;
    
    AppDelegate* app = [NSApp delegate];
    [app setSettingsParent:self];
}

- (void)swapOutSettings
{
    _settings = nil;
    
    AppDelegate* app = [NSApp delegate];
    [app setSettingsParent:nil];
}

- (id<SettingsContext> __nullable)parent
{
    return nil;
}

- (Settings* __nullable)settings
{
    return _settings;
}

@end

// ------------------------------------------------------------------------------------
static NSMutableArray* _plugins;

@implementation Plugins

static void doStage(int stage)
{
    NSMutableArray* newPlugins = [NSMutableArray new];
    LOG("Plugins:Verbose", "Stage %d", stage);

    for (PluginData* data in _plugins)
    {
        NSString* err = [data.plugin onLoad:stage];
        if (!err)
        {
            [newPlugins addObject:data];
        }
        else
        {
            LOG("Plugins", "Skipping %s (%s)", STR(data.bundleName), STR(err));
        }
    }
 
    _plugins = newPlugins;
}

+ (void)startLoading
{
    _plugins = [NSMutableArray new];
    
    AppDelegate* app = [NSApp delegate];
    
    NSString* plugins = [Paths installedDir:@"plugins"];
    LOG("Plugins:Verbose", "Loading plugins from %s", STR(plugins));

    NSError* err = nil;
    Glob* glob = [[Glob alloc] initWithGlob:@"*.plugin"];
    [Utils enumerateDir:plugins glob:glob error:&err block:^(NSString *path) {
        NSBundle* bundle = [NSBundle bundleWithPath:path];
        if (bundle)
        {
            if ([self _validBundle:bundle])
            {
                if ([bundle load])
                {
                    Class principal = [bundle principalClass];
                    LOG("Plugins:Verbose", "Instantiating %s", class_getName(principal));

                    MimsyPlugin* plugin = [principal alloc];
                    plugin = [plugin initFromApp:app bundle:bundle];
                    NSString* err = [plugin onLoad:0];
                    if (!err)
                    {
                        PluginData* data = [[PluginData alloc] init:plugin];
                        [_plugins addObject:data];
                    }
                    else
                    {
                        LOG("Plugins", "Skipping %s (%s)", STR(path.lastPathComponent), STR(err));
                    }
                }
                else
                {
                    LOG("Error", "Couldn't load %s", STR(path));
                }
            }
        }
        else
        {
            LOG("Error", "Couldn't open %s as a bundle", STR(path));
        }
    }];
    
    if (err)
    {
        NSString* reason = err.localizedFailureReason;
        LOG("Error", "Error walking '%s': %s", STR(plugins), STR(reason));
    }
}

+ (void)installFiles:(InstallFiles*)installer
{
    for (PluginData* data in _plugins)
    {
        NSString* path = data.plugin.bundle.resourcePath;
        
        NSError* error = nil;
        [Utils enumerateDeepDir:path glob:nil error:&error block:^(NSString *rsrc, bool* stop) {
            UNUSED(stop);
            
            NSArray* parts = [rsrc pathComponents];
            NSString* parent = parts.count >= 2 ? parts[parts.count - 2] : nil;
            if (![@"Resources" isEqualToString:parent])
            {
                // Install files from all directories under Resources, e.g.
                // Resources/settings, Resources/help, etc.
                [installer addSourcePath:rsrc];
                
                if ([parent isEqualToString:@"settings"])
                    [data.settingNames addObject:rsrc.lastPathComponent];
            }
        }];
        
        if (error)
        {
            NSString* reason = error.localizedFailureReason;
            LOG("Error", "Error walking '%s': %s", STR(path), STR(reason));
        }
    }
}

+ (void)finishLoading
{
    [self _loadSettings];

    doStage(1);
    doStage(2);
    doStage(3);
    
    for (PluginData* data in _plugins)
    {
        LOG("Plugins", "Loaded %s", STR(data.bundleName));
    }
}

+ (void)_loadSettings
{
    NSString* root = [Paths installedDir:@"settings"];
    
    for (PluginData* data in _plugins)
    {
        Settings* settings = [[Settings alloc] init:data.bundleName context:data];
        
        for (NSUInteger i = 0; i < data.settingNames.count; ++i)
        {
            NSError* error = nil;
            NSString* path = [root stringByAppendingPathComponent:data.settingNames[i]];
            ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
            if (parser)
            {
                [parser enumerate: ^(ConfigParserEntry* entry) {[settings addKey:entry.key value:entry.value];}];
            }
            else
            {
                NSString* reason = [error localizedFailureReason];
                LOG("Error", "Couldn't load %s:\n%s.", STR(path), STR(reason));
            }
        }
        
        [data swapInSettings:settings];
        [data.plugin onLoadSettings:[activeContext settings]];
        [data swapOutSettings];
    }
}

+ (void)refreshSettings
{
    NSString* root = [Paths installedDir:@"settings"];
   
    for (PluginData* data in _plugins)
    {
        Settings* settings = [[Settings alloc] init:data.bundleName context:data];
        
        for (NSUInteger i = 0; i < data.settingNames.count; ++i)
        {
            NSError* error = nil;
            NSString* path = [root stringByAppendingPathComponent:data.settingNames[i]];
            ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
            if (parser)
            {
                [parser enumerate: ^(ConfigParserEntry* entry) {[settings addKey:entry.key value:entry.value];}];
            }
            else
            {
                NSString* reason = [error localizedFailureReason];
                LOG("Error", "Couldn't load %s:\n%s.", STR(path), STR(reason));
            }
        }
        
        [data swapInSettings:settings];
        Settings* current = [activeContext settings];
        if (current.checksum != data.checksum)
        {
            [data.plugin onLoadSettings:current];
            data.checksum = current.checksum;
        }
        [data swapOutSettings];
    }
}

+ (void)mainChanged:(NSWindowController*)controller
{
    for (PluginData* data in _plugins)
    {
        [data.plugin onMainChanged:controller];
    }
}


+ (bool)_validBundle:(NSBundle*)bundle
{
    bool valid = true;
    
    // Package manager expects certain entries in the Info.plist file.
    NSDictionary* dict = [bundle infoDictionary];
    NSArray* required = @[@"CFBundleName", @"CFBundleVersion", @"ProjectURL", @"Email"];
    for (NSString* name in required)
    {
        NSObject* value = [dict objectForKey:name];
        if (!value)
        {
            LOG("Error", "%s is missing %s from its Info.plist file", STR(bundle.bundlePath.lastPathComponent), STR(name));
            valid = false;
        }
    }
    
    // The package manager expects a Description.rtf file.
    NSString* resources = [bundle resourcePath];
    NSString* description = [resources stringByAppendingPathComponent:@"Description.rtf"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:description])
    {
        LOG("Error", "%s is missing Description.rtf from its Resources directory", STR(bundle.bundlePath.lastPathComponent));
        valid = false;
    }
    
    // The principal class should be of the right type.
    bool found = false;
    Class pluginClass = [MimsyPlugin class];
    Class candidate = [bundle principalClass];
    while (!found && candidate)
    {
        if (candidate == pluginClass)
            found = true;
        candidate = class_getSuperclass(candidate);
    }
    
    if (!found)
    {
        LOG("Error", "%s's principalClass does not inherit from %s", STR(bundle.bundlePath.lastPathComponent), class_getName(pluginClass));
        valid = false;
    }
    
    return valid;
}

+ (void)teardown
{
    LOG("Plugins:Verbose", "Unloading plugins");
    for (PluginData* data in _plugins)
    {
        [data.plugin onUnload];
    }
    [_plugins removeAllObjects];
}

@end
