#import "DirectoryView.h"

#import "DirectoryController.h"
#import "Logger.h"

@implementation DirectoryView

- (void)keyDown:(NSEvent*)event
{
	const int ReturnKey = 36;
	
	if (event.keyCode == ReturnKey)
	{
		DirectoryController* controller = (DirectoryController*) self.window.windowController;
		[controller doubleClicked:self];
	}
	else
	{
		[super keyDown:event];
	}
}

@end
