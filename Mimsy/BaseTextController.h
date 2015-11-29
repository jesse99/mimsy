#import <Cocoa/Cocoa.h>

@class Language;

// Base class for window controllers using an NSTextView. This is used
// to support things like the find window.
@interface BaseTextController : NSWindowController

+ (BaseTextController*)frontmost;

- (NSTextView*)getTextView;
- (NSUInteger)getEditCount;

- (void)showInfo:(NSString*)text;
- (void)showWarning:(NSString*)text;

@property Language* fullLanguage;

@end
