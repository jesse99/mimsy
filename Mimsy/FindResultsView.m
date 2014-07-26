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
		[super keyDown:event];
	}
}

@end

