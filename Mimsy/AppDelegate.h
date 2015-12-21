#import "MimsyPlugins.h"
#import "Settings.h"

@class ProcFileSystem;
@class TextController;

typedef void (^NullaryBlock)();
typedef void (^InvokeTextCommandBlock)(id<MimsyTextView> _Nonnull);
typedef NSString* _Nullable (^TextContextMenuItemTitleBlock)(id<MimsyTextView> _Nonnull);
typedef NSString* __nullable (^ __nonnull ProjectContextMenuItemTitleBlock)(NSArray<MimsyPath*>* __nonnull, NSArray<MimsyPath*>* __nonnull);
typedef void (^TextRangeBlock)(id<MimsyTextView> _Nonnull, NSRange);

typedef void (^ __nonnull InvokeProjectCommandBlock)(NSArray<MimsyPath*>* __nonnull, NSArray<MimsyPath*>* __nonnull);

void initLogGlobs(void);

@interface TextContextItem : NSObject

@property (strong) TextContextMenuItemTitleBlock _Nonnull title;
@property (strong) InvokeTextCommandBlock _Nonnull invoke;

@end

@interface ProjectContextItem : NSObject

@property (strong) ProjectContextMenuItemTitleBlock _Nonnull title;
@property (strong) InvokeProjectCommandBlock _Nonnull invoke;

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowRestoration, MimsyApp, SettingsContext>

- (void)applicationDidBecomeActive:(NSNotification* _Nonnull)notification;
+ (void)restoreWindowWithIdentifier:(NSString* _Nonnull)identifier state:(NSCoder* _Nonnull)state completionHandler:(void (^ _Nonnull)(NSWindow* _Nullable, NSError* _Nullable))handler;

- (void)saveAllDocuments:(id _Nullable)sender;

- (void)openWithMimsy:(NSURL* _Nonnull)url;
- (IBAction)openAsBinaryAction:(id _Nullable)sender;
- (void)searchSite:(id _Nullable)sender;
- (void)openLatestInTimeMachine:(id _Nullable)sender;
- (void)openTimeMachine:(id _Nullable)sender;

// This works like performSelector:withObject:afterDelay: except that calling it with a
// name that is pending is a no-op.
+ (void)execute:(NSString* _Nonnull)key withSelector:(SEL _Nonnull)selector withObject:(id _Nullable)object afterDelay:(NSTimeInterval)delay;
+ (void)execute:(NSString* _Nonnull)key afterDelay:(NSTimeInterval)delay withBlock:(NullaryBlock _Nonnull)block;

// This works like performSelector:withObject:afterDelay: except that if called when the
// block is pending it's execution time is pushed back by delay.
+ (void)execute:(NSString* _Nonnull)key withSelector:(SEL _Nonnull)selector withObject:(id _Nullable)object deferBy:(NSTimeInterval)delay;
+ (void)execute:(NSString* _Nonnull)key deferBy:(NSTimeInterval)delay withBlock:(NullaryBlock _Nonnull)block;

- (id<SettingsContext> _Nullable)parent;
- (Settings* _Nonnull)settings;

- (void)invokeTextViewHook:(enum TextViewNotification)kind view:(id<MimsyTextView> _Nonnull)view;
- (bool)invokeTextViewKeyHook:(NSString* _Nonnull)key view:(id<MimsyTextView> _Nonnull)view;

- (NSArray* _Nullable)noSelectionItems:(enum NoTextSelectionPos)pos;
- (NSArray* _Nullable)withSelectionItems:(enum WithTextSelectionPos)pos;
- (NSArray* _Nullable)projectItems;
- (NSDictionary* _Nonnull)applyElementHooks;

- (void)installSettingsPath:(MimsyPath* _Nonnull)path;
- (void)setSettingsParent:(id<SettingsContext> _Nullable)parent;

@property (readonly) bool inited;
@property (readonly) ProcFileSystem*_Nonnull procFileSystem;
@property (weak) IBOutlet NSMenu *searchMenu;
@property (weak) IBOutlet NSMenu *textMenu;
@property (strong) IBOutlet NSMenu* _Nonnull recentDirectoriesMenu;

@end
