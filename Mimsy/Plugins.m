#import "Plugins.h"

#import "AppDelegate.h"
#import "Glob.h"
#import "MimsyPlugins.h"
#import "Paths.h"
#import "Utils.h"

static NSMutableArray* _plugins;

@implementation Plugins

static void doStage(int stage)
{
    NSMutableArray* newPlugins = [NSMutableArray new];

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
    
    NSError* err = nil;
    NSString* plugins = [Paths installedDir:@"plugins"];
    Glob* glob = [[Glob alloc] initWithGlob:@"*.plugin"];
    [Utils enumerateDir:plugins glob:glob error:&err block:^(NSString *path) {
        NSBundle* bundle = [NSBundle bundleWithPath:path];
        if (bundle)
        {
            if ([bundle load])
            {
                Class principal = [bundle principalClass];
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
                LOG("Warn", "Couldn't load %s", STR(path));
            }
        }
        else
        {
            LOG("Warn", "Couldn't open %s as a bundle", STR(path));
        }
    }];

    doStage(1);
    doStage(2);
    doStage(3);
}

+ (void)teardown
{
    for (MimsyPlugin* plugin in _plugins)
    {
        [plugin onUnload];
    }
    [_plugins removeAllObjects];
}

@end
