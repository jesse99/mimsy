#import "TextView.h"

#import "TextController.h"

@implementation TextView
{
	__weak TextController* _controller;
}

- (void)onOpened:(TextController*)controller
{
	_controller = controller;
}

- (void)paste:(id)sender
{
	[super paste:sender];
	
	TextController* controller = _controller;
	if (controller)
		[controller resetAttributes];
}

@end
