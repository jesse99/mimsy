#import "FindResultsController.h"

#import "Assert.h"
#import "FindInFiles.h"

static NSMutableArray* opened;

@implementation FindResultsController
{
	FindInFiles* _finder;		// retain a reference to keep the finder alive
}

- (id)initWith:(FindInFiles*)finder
{
	if (!opened)
		opened = [NSMutableArray new];
	
	self = [super initWithWindowNibName:@"FindResultsWindow"];
    if (self)
	{
		_finder = finder;
		[self showWindow:self.window];
		[self.window makeKeyAndOrderFront:self];

		[opened addObject:self];
    }
    
    return self;
}

- (void)windowWillClose:(NSNotification*)notification
{
	UNUSED(notification);
	
	[opened removeObject:self];
}

@end
