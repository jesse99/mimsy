#import <Cocoa/Cocoa.h>

#import "BaseTextController.h"

@class Language, TextController, TextStyles, TextView;

typedef void (^LayoutCallback)(TextController* controller);

// Contoller used to mediate between text documents and the NSTextView in the associated window.
@interface TextController : BaseTextController

+ (TextController*)frontmost;
+ (void)enumerate:(void (^)(TextController* controller, bool* stop))block;
+ (TextController*)find:(NSString*)path;

- (void)open;
- (void)onPathChanged;
- (bool)isWordWrapping;
- (void)toggleWordWrap;
- (void)resetAttributes;
- (void)changeStyle:(NSString*)path;
- (void)resetStyles;
- (void)showLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width;
- (NSString*)path;

- (void)shiftLeft:(id)sender;
- (void)shiftRight:(id)sender;

// Returns the language element name the range is within, e.g. String, Comment, Identifier, etc.
// Returns nil if the window has no language or the range crosses multiple elements. Note that
// this returns a lower case version of the element name.
- (NSString*)getElementNameFor:(NSRange)range;

- (bool)isBrace:(unichar)ch;
- (bool)isOpenBrace:(NSUInteger)index;
- (bool)isCloseBrace:(NSUInteger)index;

- (void)registerBlockWhenLayoutCompletes:(LayoutCallback)block;

- (NSTextView*)getTextView;
- (NSUInteger)getEditCount;

@property IBOutlet TextView* textView;
@property IBOutlet __weak NSScrollView* scrollView;
@property NSAttributedString* attributedText;
@property (readonly) NSString* text;
@property (readonly) NSUInteger editCount;
@property (readonly) TextStyles* styles;
@property NSString* customTitle;

@end
