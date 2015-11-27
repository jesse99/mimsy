#import "MimsyPlugins.h"
#import "Settings.h"

@class ProcFileSystem;

typedef void (^NullaryBlock)();

void initLogGlobs(void);

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowRestoration, MimsyApp, SettingsContext>

- (void)applicationDidBecomeActive:(NSNotification *)notification;
+ (void)restoreWindowWithIdentifier:(NSString*)identifier state:(NSCoder*)state completionHandler:(void (^)(NSWindow*, NSError*))handler;

- (void)saveAllDocuments:(id)sender;

- (void)openWithMimsy:(NSURL*)url;
- (IBAction)openAsBinary:(id)sender;
- (void)searchSite:(id)sender;
- (void)openLatestInTimeMachine:(id)sender;
- (void)openTimeMachine:(id)sender;

+ (void)appendContextMenu:(NSMenu*)menu;

// This works like performSelector:withObject:afterDelay: except that calling it with a
// name that is pending is a no-op.
+ (void)execute:(NSString*)key withSelector:(SEL)selector withObject:(id)object afterDelay:(NSTimeInterval)delay;
+ (void)execute:(NSString*)key afterDelay:(NSTimeInterval)delay withBlock:(NullaryBlock)block;

// This works like performSelector:withObject:afterDelay: except that if called when the
// block is pending it's execution time is pushed back by delay.
+ (void)execute:(NSString*)key withSelector:(SEL)selector withObject:(id)object deferBy:(NSTimeInterval)delay;
+ (void)execute:(NSString*)key deferBy:(NSTimeInterval)delay withBlock:(NullaryBlock)block;

#if OLD_EXTENSIONS
- (void)runFTest:(id)sender;
- (void)runFTests:(id)sender;
#endif

- (id<SettingsContext>)parent;
- (Settings*)settings;

@property (readonly) bool inited;
@property (readonly) ProcFileSystem *procFileSystem;
@property (weak) IBOutlet NSMenu *searchMenu;
@property (weak) IBOutlet NSMenu *textMenu;
@property (strong) IBOutlet NSMenu *recentDirectoriesMenu;

@end
