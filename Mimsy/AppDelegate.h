#import <Foundation/Foundation.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

- (void)applicationDidBecomeActive:(NSNotification *)notification;

- (IBAction)openAsBinary:(id)sender;

@end
