#import <Cocoa/Cocoa.h>

@interface IntegerDialogController : NSWindowController

- (IntegerDialogController*)initWithTitle:(NSString*)title value:(int)value;

@property bool hasValue;

// Use intValue or integerValue to get the result.
@property (strong) IBOutlet NSTextField *textField;

@end
