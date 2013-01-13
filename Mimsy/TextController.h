#import <Cocoa/Cocoa.h>

@class Language, TextStyles, TextView;

// Contoller used to mediate between text documents and the NSTextView in the associated window.
@interface TextController : NSWindowController

- (void)open;
- (void)onPathChanged;
- (void)toggleWordWrap;
- (void)resetAttributes;
- (void)changeStyle:(NSString*)path;
+ (TextController*)frontmost;

@property IBOutlet TextView* textView;
@property IBOutlet NSScrollView *scrollView;
@property NSAttributedString* attributedText;
@property (readonly) NSString* text;
@property (readonly) NSUInteger editCount;
@property (readonly) TextStyles* styles;
@property Language* language;

@end
