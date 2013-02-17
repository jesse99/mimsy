#import "DirectoryController.h"

#import "FolderItem.h"
#import "Logger.h"

static NSMutableArray* _windows;

@implementation DirectoryController
{
	NSString* _path;
	FolderItem* _root;
}

- (id)initWithDir:(NSString*)path
{
	self = [super initWithWindowNibName:@"DirectoryWindow"];
	if (self)
	{
		_path = path;
		
		if (!_windows)
			_windows = [NSMutableArray new];
		[_windows addObject:self];				// need to keep a reference to the controller around (using the window won't retain the controller)
		
//		m_table.setDoubleAction("doubleClicked:");
//		m_table.setTarget(this);
		
		_root = [[FolderItem alloc] initWithPath:path];
		NSOutlineView* table = self.table;
		if (table)
			[table reloadData];

		[self.window setTitle:[path lastPathComponent]];
		[self.window makeKeyAndOrderFront:self];
	}
	return self;
}

- (void)windowWillClose:(NSNotification*)notification
{
	(void) notification;
	
	[_windows removeObject:self];
}

- (NSInteger)outlineView:(NSOutlineView*)table numberOfChildrenOfItem:(FileSystemItem*)item
{
	(void) table;
	
	if (!_root)
		return 0;
	
	return (NSInteger) (item == nil ? _root.count : [item count]);
}

- (BOOL)outlineView:(NSOutlineView*)table isItemExpandable:(FileSystemItem*)item
{
	(void) table;
	
	return item == nil ? YES : [item isExpandable];
}

- (id)outlineView:(NSOutlineView*)table child:(NSInteger)index ofItem:(FileSystemItem*)item
{
	(void) table;
	
	if (!_root)
		return nil;
	
	return item == nil ? _root[(NSUInteger) index] : item[(NSUInteger) index];
}

- (id)outlineView:(NSOutlineView*)table objectValueForTableColumn:(NSTableColumn*)column byItem:(FileSystemItem*)item
{
	(void) table;
	
	if (!_root)
		return @"";
	
	if ([column.identifier isEqualToString:@"1"])
		return item == nil ? _root.name : [item name];
	else
		return item == nil ? _root.bytes : [item bytes];
}

@end
