// Window used to display (normally transient) warnings.
#import <Foundation/Foundation.h>

@interface WarningWindow : NSObject

- (id)init;

- (void)show:(NSWindow*)parent withText:(NSString*)text red:(int)red green:(int)green blue:(int)blue;

@end
