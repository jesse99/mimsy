#import "TextController.h"

#import "TextDocument.h"

@interface TextController ()

@end

@implementation TextController

- (id)init
{
    self = [super initWithWindowNibName:@"TextDocument"];
    if (self)
	{
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[[self document] controllerDidLoad];
}

- (NSTextView*) view
{
	return theView;
}

@end
