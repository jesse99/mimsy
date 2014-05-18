#import <Foundation/Foundation.h>

@class LocalSettings;

void initLogLevels(void);

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowRestoration>

- (void)applicationDidBecomeActive:(NSNotification *)notification;
+ (void)restoreWindowWithIdentifier:(NSString*)identifier state:(NSCoder*)state completionHandler:(void (^)(NSWindow*, NSError*))handler;

- (void)openWithMimsy:(NSURL*)url;
- (IBAction)openAsBinary:(id)sender;
- (void)searchSite:(id)sender;
- (void)openTimeMachine:(id)sender;

+ (void)appendContextMenu:(NSMenu*)menu;

- (void)runFTest:(id)sender;
- (void)runFTests:(id)sender;

@property (readonly) LocalSettings *settings;
@property (weak) IBOutlet NSMenu *searchMenu;
@property (weak) IBOutlet NSMenu *textMenu;

@end
