#import <Foundation/Foundation.h>

void initLogLevels(void);

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowRestoration>

- (void)applicationDidBecomeActive:(NSNotification *)notification;
+ (void)restoreWindowWithIdentifier:(NSString*)identifier state:(NSCoder*)state completionHandler:(void (^)(NSWindow*, NSError*))handler;

- (IBAction)openAsBinary:(id)sender;
- (void)searchSite:(id)sender;

- (void)runFTest:(id)sender;
- (void)runFTests:(id)sender;

@property (weak) IBOutlet NSMenu *searchMenu;

@end
