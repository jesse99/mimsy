#import "Plugins.h"

#import "AppDelegate.h"
#import "Glob.h"
#import "MimsyPlugins.h"
#import "Paths.h"
#import "Utils.h"

#include <objc/runtime.h>

static NSMutableArray* _plugins;

@implementation Plugins

static void doStage(int stage)
{
    NSMutableArray* newPlugins = [NSMutableArray new];
    LOG("Plugins:Verbose", "Stage %d", stage);

    for (MimsyPlugin* plugin in _plugins)
    {
        NSString* err = [plugin onLoad:stage];
        if (!err)
        {
            [newPlugins addObject:plugin];
        }
        else
        {
            LOG("Plugins", "Skipping %s (%s)", STR(plugin.bundle.bundlePath.lastPathComponent), STR(err));
        }
    }
 
    _plugins = newPlugins;
}

+ (void)startup
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
                        [_plugins addObject:plugin];
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

    doStage(1);
    doStage(2);
    doStage(3);

    for (MimsyPlugin* plugin in _plugins)
    {
        LOG("Plugins", "Loaded %s", STR(plugin.bundle.bundlePath.lastPathComponent));
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
    for (MimsyPlugin* plugin in _plugins)
    {
        [plugin onUnload];
    }
    [_plugins removeAllObjects];
}

@end
