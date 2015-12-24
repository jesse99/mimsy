#import <Cocoa/Cocoa.h>

@interface StringDialogController : NSWindowController

/// Call [NSApp runModalForWindow:controller.window] after this.
- (StringDialogController*)initWithTitle:(NSString*)title value:(NSString*)value;

@property bool hasValue;

/// Use stringValue to get the result.
@property (strong) IBOutlet NSTextField *textField;

@end
