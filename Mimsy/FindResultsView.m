#import "FindResultsView.h"

#import "FindResultsController.h"
#import "Logger.h"

@implementation FindResultsView

- (void)keyDown:(NSEvent*)event
{
	const int ReturnKey = 36;
	
	if (event.keyCode == ReturnKey)
	{
		FindResultsController* controller = (FindResultsController*) self.window.windowController;
		[controller doubleClicked:self];
	}
	else
	{
		LOG_DEBUG("Mimsy", "keyCode = %u, flags = %lX", event.keyCode, event.modifierFlags);
		[super keyDown:event];
	}
}

@end

