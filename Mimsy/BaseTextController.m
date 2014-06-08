#import "BaseTextController.h"

#import "Assert.h"
#import "FindController.h"
#import "FindInFilesController.h"
#import "OpenSelection.h"
#import "WarningWindow.h"

@implementation BaseTextController
{
	WarningWindow* _warningWindow;	
}

+ (BaseTextController*)frontmost
{
	for (NSWindow* window in [NSApp orderedWindows])
	{
		if (window.isVisible || window.isMiniaturized)
			if (window.windowController)
				if ([window.windowController isKindOfClass:[BaseTextController class]])
					return window.windowController;
	}
	
	return nil;
}

- (NSTextView*)getTextView
{
	ASSERT(false);		// subclasses need to override this
	return nil;
}

- (NSUInteger)getEditCount
{
	ASSERT(false);		// subclasses need to override this
	return 0;
}

- (void)showInfo:(NSString*)text
{
	if (!_warningWindow)
		_warningWindow = [WarningWindow new];
	
	[_warningWindow show:self.window withText:text red:135 green:206 blue:250];
}

- (void)showWarning:(NSString*)text
{
	if (!_warningWindow)
		_warningWindow = [WarningWindow new];
	
	[_warningWindow show:self.window withText:text red:250 green:128 blue:114];
}

- (void)find:(id)sender
{
	UNUSED(sender);
	
	[FindController show];
}


- (void)findNext:(id)sender
{
	UNUSED(sender);
	
	FindController* controller = [FindController getController];
	[controller find:self];
}

- (void)findPrevious:(id)sender
{
	UNUSED(sender);
	
	FindController* controller = [FindController getController];
	[controller findPrevious:self];
}

- (void)useSelection:(id)sender
{
	UNUSED(sender);
	
	NSRange range = self.getTextView.selectedRange;
	NSString* selection = [self.getTextView.textStorage.string substringWithRange:range];
	
	FindController* controller = [FindController getController];
	controller.findText = selection;

	FindInFilesController* controller2 = [FindInFilesController getController];
	controller2.findText = selection;
}

- (void)openSelection:(id)sender
{
	UNUSED(sender);
	
	NSTextStorage* storage = self.getTextView.textStorage;
	NSRange range = self.getTextView.selectedRange;
	if (!openTextRange(storage, range))
		NSBeep();
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	BOOL enabled = NO;
	
	SEL sel = [item action];
	if (sel == @selector(useSelection:) || sel == @selector(openSelection:))
	{
		NSRange range = self.getTextView.selectedRange;
		enabled = range.length > 0;
	}
	else if (sel == @selector(findNext:) || sel == @selector(findPrevious:))
	{
		FindController* controller = [FindController getController];
		enabled = controller.findText.length > 0;
	}
	else if ([self respondsToSelector:sel])
	{
		enabled = YES;
	}
	else if ([super respondsToSelector:@selector(validateMenuItem:)])
	{
		enabled = [super validateMenuItem:item];
	}
	
	return enabled;
}

@end
