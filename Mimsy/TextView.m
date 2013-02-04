#import "TextView.h"

#import "Logger.h"
#import "TextController.h"

@implementation TextView
{
	__weak TextController* _controller;
	bool _changingBackColor;
	bool _restored;
}

- (void)onOpened:(TextController*)controller
{
	_controller = controller;
}

- (void)restoreStateWithCoder:(NSCoder*)coder
{
	[super restoreStateWithCoder:coder];
	_restored = true;
}

- (bool)restored
{
	return _restored;
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
	BOOL valid = NO;
	
	if (item.action == @selector(changeBackColor:))
	{
		// If the document has a language then the back color is set by a styles file.
		TextController* controller = _controller;
		if (controller)
			valid = controller.language == nil;
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
	[panel setColor:[NSColor whiteColor]];
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
			TextController* controller = _controller;
			if (controller)
			{
				NSColor* color = [sender color];
				[self setBackgroundColor:color];
				[controller.document updateChangeCount:NSChangeDone | NSChangeDiscardable];
			}
		}
		else
		{
			[super changeColor:sender];
		}
	}
}

@end
