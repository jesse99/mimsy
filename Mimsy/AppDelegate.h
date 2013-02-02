#import <Foundation/Foundation.h>

void initLogLevels(void);

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

- (void)applicationDidBecomeActive:(NSNotification *)notification;

- (IBAction)openAsBinary:(id)sender;

- (void)runFTest:(id)sender;
- (void)runFTests:(id)sender;

@end
