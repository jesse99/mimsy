#import "SelectNameController.h"

#import "Assert.h"

@implementation SelectNameController
{
	NSArray* _names;
}

- (SelectNameController*)initWithTitle:(NSString*)title names:(NSArray*)names
{
	self = [super initWithWindowNibName:@"SelectName"];
	if (self)
	{
		self->_names = names;
		
		NSTableView* table = self.table;
		if (table)
			[table reloadData];
		
		[self.window setTitle:title];
		
		[self showWindow:self];
		[self.window makeKeyAndOrderFront:NSApp];
	}

	return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

- (IBAction)pressedOK:(id)sender
{
	UNUSED(sender);
	
	NSTableView* table = self.table;
	if (table)
		self.selectedRows = table.selectedRowIndexes;

	// Explicitly closing the window can prevent exceptions if our caller opens up new
	// windows (this was happening with TimeMachine). It looked like the first responder
	// in this window was resigning while the window was being torn down.
	[self.window close];
	[NSApp stopModalWithCode:NSOKButton];
}

- (IBAction)pressedCancel:(id)sender
{
	UNUSED(sender);
	[NSApp stopModalWithCode:NSCancelButton];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)view
{
	UNUSED(view);
	
	return (NSInteger) _names.count;
}

- (id)tableView:(NSTableView*)view objectValueForTableColumn:(NSTableColumn*)column row:(NSInteger)row
{
	UNUSED(view);
	UNUSED(column);
	
	return _names[(NSUInteger) row];
}

@end
