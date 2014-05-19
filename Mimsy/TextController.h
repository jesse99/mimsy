#import <Cocoa/Cocoa.h>

@class Language, TextStyles, TextView;

// Contoller used to mediate between text documents and the NSTextView in the associated window.
@interface TextController : NSWindowController

+ (TextController*)frontmost;
+ (void)enumerate:(void (^)(TextController* controller))block;

- (void)open;
- (void)onPathChanged;
- (bool)isWordWrapping;
- (void)toggleWordWrap;
- (void)resetAttributes;
- (void)changeStyle:(NSString*)path;
- (void)resetStyles;
- (void)showLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width;
- (NSString*)path;
- (NSTextView*)getTextView;

// Returns the language element name the range is within, e.g. String, Comment, Identifier, etc.
// Returns nil if the window has no language or the range crosses multiple elements. Note that
// this returns a lower case version of the element name.
- (NSString*)getElementNameFor:(NSRange)range;

- (void)showInfo:(NSString*)text;
- (void)showWarning:(NSString*)text;

@property IBOutlet TextView* textView;
@property IBOutlet __weak NSScrollView* scrollView;
@property NSAttributedString* attributedText;
@property (readonly) NSString* text;
@property (readonly) NSUInteger editCount;
@property (readonly) TextStyles* styles;
@property Language* language;
@property NSString* customTitle;

@end
