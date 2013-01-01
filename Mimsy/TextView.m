#import "TextView.h"

#import "Logger.h"
#import "TextController.h"

@implementation TextView
{
	__weak TextController* _controller;
	bool _changingBackColor;
}

- (void)onOpened:(TextController*)controller
{
	_controller = controller;
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
	BOOL valid = NO;
	
	if (item.action == @selector(changeBackColor:))
	{
		// If the document has a language then the back color is set by a styles file.
		TextController* controller = _controller;
		if (controller)
			valid = _controller.language == nil;
	}
	else if ([self respondsToSelector:item.action])
	{
		valid = YES;
	}
	else if ([super respondsToSelector:@selector(validateUserInterfaceItem:)])
	{
		valid = [super validateUserInterfaceItem:item];
	}
	
	return valid;
}

- (void)paste:(id)sender
{
	[super paste:sender];
	
	TextController* controller = _controller;
	if (controller)
		[controller resetAttributes];
}

- (void)orderFrontColorPanel:(id)sender
{
	NSColorPanel* panel = [NSColorPanel sharedColorPanel];
	[panel setContinuous:YES];
	[panel setColor:[NSColor blackColor]];
	_changingBackColor = false;
	[NSApp orderFrontColorPanel:sender];
}

- (void)changeBackColor:(id)sender
{
	(void) sender;
	
	NSColorPanel* panel = [NSColorPanel sharedColorPanel];
	[panel setContinuous:YES];
	[panel setColor:self.backgroundColor];
	_changingBackColor = true;
	[panel makeKeyAndOrderFront:self];
}

// NSColorPanel is rather awful:
// 1) This method is always called on the first responder call setAction.
// 2) When the panel is closed the view (and every other document window!) is called
// with the original color.
- (void)changeColor:(id)sender
{
	if ([sender isVisible])
	{
		if (_changingBackColor)
		{
			NSColor* color = [sender color];
			[self setBackgroundColor:color];
		}
		else
		{
			[super changeColor:sender];
		}
	}
}

@end
