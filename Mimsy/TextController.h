#import <Cocoa/Cocoa.h>

@class Language;

// Contoller used to mediate between text documents and the NSTextView in the associated window.
@interface TextController : NSWindowController

- (void)open;
- (void)onPathChanged;
- (void)toggleWordWrap;

@property IBOutlet NSTextView* textView;
@property IBOutlet NSScrollView *scrollView;
@property NSAttributedString* attributedText;
@property (readonly) NSString* text;
@property Language* language;

@end
