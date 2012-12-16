#import <Cocoa/Cocoa.h>

// Contoller used to mediate between text documents and the NSTextView in the associated window.
@interface TextController : NSWindowController

- (void) open;

@property IBOutlet NSTextView* view;

@end
