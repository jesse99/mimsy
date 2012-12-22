#import <Cocoa/Cocoa.h>

// Contoller used to mediate between text documents and the NSTextView in the associated window.
@interface TextController : NSWindowController

- (void)open;
- (void)onPathChanged;
- (void)toggleWordWrap;

@property IBOutlet NSTextView* textView;
@property IBOutlet NSScrollView *scrollView;
@property (readonly) NSString* text;

@end
