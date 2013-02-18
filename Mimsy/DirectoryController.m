#import "DirectoryController.h"

#import "DirectoryWatcher.h"
#import "FolderItem.h"
#import "Logger.h"

static NSMutableArray* _windows;

@implementation DirectoryController
{
	NSString* _path;
	FolderItem* _root;
	DirectoryWatcher* _watcher;
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
		
		_watcher = [[DirectoryWatcher alloc] initWithPath:path latency:1.0 block:
			^(NSArray* paths) {[self _dirChanged:paths];}];

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
	
	return item == nil ? _root[(NSUInteger) index] : item[(NSUInteger) index];
}

- (id)outlineView:(NSOutlineView*)table objectValueForTableColumn:(NSTableColumn*)column byItem:(FileSystemItem*)item
{
	(void) table;
	
	if ([column.identifier isEqualToString:@"1"])
		return item == nil ? _root.name : [item name];
	else
		return item == nil ? _root.bytes : [item bytes];
}

- (void) _dirChanged:(NSArray*)paths
{
	// Update which ever items were opened.
	for (NSString* path in paths)
	{
		FileSystemItem* item = [_root find:path];
		if (item)
		{
			// Continuum used the argument to reload to manually preserve the selection.
			// But it seems that newer versions of Cocoa do a better job at preserving
			// the selection.
			if ([item reload:nil])
			{
				NSOutlineView* table = self.table;
				if (table)
					[table reloadItem:item == _root ? nil : item reloadChildren:true];
			}
		}
	}
}

@end
