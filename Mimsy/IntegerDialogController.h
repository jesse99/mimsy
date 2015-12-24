#import <Cocoa/Cocoa.h>

@interface IntegerDialogController : NSWindowController

/// Call [NSApp runModalForWindow:controller.window] after this.
- (IntegerDialogController*)initWithTitle:(NSString*)title value:(int)value;

@property bool hasValue;

/// Use intValue or integerValue to get the result.
@property (strong) IBOutlet NSTextField *textField;

@end
