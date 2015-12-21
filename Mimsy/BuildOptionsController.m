#import "BuildOptionsController.h"

#import "DirectoryController.h"
#import "Glob.h"

@implementation BuildOptionsController
{
	__weak DirectoryController* _directoryController;
}

- (BuildOptionsController*)init
{
    return [super initWithWindowNibName:@"BuildOptions"];
}

- (void)openWith:(DirectoryController*)controller
{
	_directoryController = controller;
	_targets = [controller.targetGlobs map:^id(Glob* item) {return item.description;}];
	_flags  = [NSMutableArray arrayWithArray:controller.flags];
	for (NSUInteger i = 0; i < 20; ++i)
	{
		[_targets addObject:@""];
		[_flags addObject:@""];
	}
	
	NSTableView* table = self.table;
	if (table)
		[table reloadData];
	
	NSString* title = [[controller.path lastComponent] stringByAppendingString:@" Build Flags"];
	[self.window setTitle:title];
	
	[self showWindow:self];
	[self.window makeKeyAndOrderFront:NSApp];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

- (IBAction)okPressed:(id)sender
{
	UNUSED(sender);
	
	// Cheesy way to deselect the current field so that setObjectValue is called.
	[[self window] makeFirstResponder: nil];
	
	[NSApp stopModalWithCode:NSModalResponseOK];
	[self.window orderOut:self];
	
	DirectoryController* controller = _directoryController;
	if (controller)
	{
		[controller.targetGlobs removeAllObjects];
		[controller.flags removeAllObjects];
		for (NSUInteger i = 0; i < _targets.count; ++i)
		{
			if ([_targets[i] length] > 0)		// doesn't make a lot of sense to have a target without flags but it could be handy as a place holder
			{
				[controller.targetGlobs addObject:[[Glob alloc] initWithGlob:_targets[i]]];
				[controller.flags addObject:_flags[i]];
			}
		}
		[controller saveBuildFlags];
	}
}

- (IBAction)cancelPressed:(id)sender
{
	UNUSED(sender);
	[NSApp stopModalWithCode:NSModalResponseCancel];
	[self.window orderOut:self];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)view
{
	UNUSED(view);
	
	return (NSInteger) _targets.count;
}

- (id)tableView:(NSTableView*)view objectValueForTableColumn:(NSTableColumn*)column row:(NSInteger)row
{
	UNUSED(view);
	
	id value = nil;
	
	if ([column.identifier isEqualToString:@"target"])
	{
		value = _targets[(NSUInteger) row];
	}
	else if ([column.identifier isEqualToString:@"flags"])
	{
		value = _flags[(NSUInteger) row];
	}
	else
	{
		ASSERT(false);
	}
	
	return value;
}

- (void)tableView:(NSTableView*)view setObjectValue:(id)newValue forTableColumn:(NSTableColumn*)column row:(NSInteger)row
{
	UNUSED(view);

	if ([column.identifier isEqualToString:@"target"])
	{
		_targets[(NSUInteger) row] = newValue;
	}
	else if ([column.identifier isEqualToString:@"flags"])
	{
		_flags[(NSUInteger) row] = newValue;
	}
	else
	{
		ASSERT(false);
	}
}

@end
