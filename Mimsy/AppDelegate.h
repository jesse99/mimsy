#import <Foundation/Foundation.h>

void initLogLevels(void);

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowRestoration>

- (void)applicationDidBecomeActive:(NSNotification *)notification;
+ (void)restoreWindowWithIdentifier:(NSString*)identifier state:(NSCoder*)state completionHandler:(void (^)(NSWindow*, NSError*))handler;

- (void)openWithMimsy:(NSURL*)url;
- (IBAction)openAsBinary:(id)sender;
- (void)searchSite:(id)sender;
- (void)openTimeMachine:(id)sender;

+ (void)appendContextMenu:(NSMenu*)menu;

// Use the Settings class instead of this.
+ (NSString*)findSetting:(NSString*)name;

- (void)runFTest:(id)sender;
- (void)runFTests:(id)sender;

@property (weak) IBOutlet NSMenu *searchMenu;
@property (weak) IBOutlet NSMenu *textMenu;

@end
