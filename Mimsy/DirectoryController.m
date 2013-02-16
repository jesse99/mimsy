#import "DirectoryController.h"

#import "Logger.h"

static NSMutableArray* _windows;

@implementation DirectoryController

- (id)initWithDir:(NSString*)path
{
	(void) path;
	self = [super initWithWindowNibName:@"DirectoryWindow"];
	if (self)
	{
		if (!_windows)
			_windows = [NSMutableArray new];
		[_windows addObject:self.window];		// need to keep a reference to the window around
		
		[self.window setFrameAutosaveName:<#(NSString *)#>]
		[self.window setTitle:[path lastPathComponent]];
		[self.window makeKeyAndOrderFront:self];
	}
	return self;
}

- (void)windowWillClose:(NSNotification*)notification
{
	(void)notification;
	
	[_windows removeObject:self.window];
}

@end
