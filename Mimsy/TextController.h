#import <Cocoa/Cocoa.h>

@class Language, TextStyles, TextView;

// Contoller used to mediate between text documents and the NSTextView in the associated window.
@interface TextController : NSWindowController

+ (TextController*)frontmost;
+ (void)enumerate:(void (^)(TextController* controller))block;

- (void)open;
- (void)onPathChanged;
- (void)toggleWordWrap;
- (void)resetAttributes;
- (void)changeStyle:(NSString*)path;
- (void)resetStyles;
- (void)showLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width;

@property IBOutlet TextView* textView;
@property IBOutlet __weak NSScrollView* scrollView;
@property NSAttributedString* attributedText;
@property (readonly) NSString* text;
@property (readonly) NSUInteger editCount;
@property (readonly) TextStyles* styles;
@property Language* language;

@end
