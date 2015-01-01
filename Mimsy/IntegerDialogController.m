#import "IntegerDialogController.h"

@implementation IntegerDialogController

- (IntegerDialogController*)initWithTitle:(NSString*)title value:(int)value
{
    self = [super initWithWindowNibName:@"IntegerDialog"];
    if (self)
    {
        [self.window setTitle:title];
        
        [self showWindow:self];
        [self.textField setIntValue:value];
        [self.window makeKeyAndOrderFront:NSApp];
    }
    
    return self;
}

- (IBAction)pressedOK:(id)sender
{
    UNUSED(sender);
    
    self.hasValue = true;
    
    [self.window close];
    [NSApp stopModalWithCode:NSModalResponseOK];
}

- (IBAction)pressedCancel:(id)sender
{
    UNUSED(sender);
    
    [self.window close];
    [NSApp stopModalWithCode:NSModalResponseCancel];
}

@end

