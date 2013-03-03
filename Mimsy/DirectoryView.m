#import "DirectoryView.h"

#import "DirectoryController.h"
#import "Logger.h"

@implementation DirectoryView

- (void)keyDown:(NSEvent*)event
{
	const int ReturnKey = 36;
	const int DeleteKey = 51;
	
	if (event.keyCode == DeleteKey && (event.modifierFlags & NSCommandKeyMask))
	{
		DirectoryController* controller = (DirectoryController*) self.window.windowController;
		[controller deleted:self];
	}
	else if (event.keyCode == ReturnKey)
	{
		DirectoryController* controller = (DirectoryController*) self.window.windowController;
		[controller doubleClicked:self];
	}
	else
	{
		LOG_DEBUG("Mimsy", "keyCode = %u, flags = %lX", event.keyCode, event.modifierFlags);
		[super keyDown:event];
	}
}

@end

