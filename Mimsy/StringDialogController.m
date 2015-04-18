#import "StringDialogController.h"

@implementation StringDialogController

- (StringDialogController*)initWithTitle:(NSString*)title value:(NSString*)value
{
    self = [super initWithWindowNibName:@"StringDialog"];
    if (self)
    {
        [self.window setTitle:title];
        
        [self showWindow:self];
        [self.textField setStringValue:value];
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

