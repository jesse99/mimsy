#import "FindResultsController.h"

#import "Assert.h"
#import "FindInFiles.h"
#import "OpenFile.h"
#import "PersistentRange.h"

static NSMutableArray* opened;

@implementation FindResultsController
{
	FindInFiles* _finder;			// retain a reference to keep the finder alive
	NSMutableArray* _paths;
	NSMutableDictionary* _data;		// path => matches
	
	CGFloat _pathHeight;
	CGFloat _matchHeight;
}

- (id)initWith:(FindInFiles*)finder
{
	if (!opened)
		opened = [NSMutableArray new];
	
	self = [super initWithWindowNibName:@"FindResultsWindow"];
    if (self)
	{
		NSWindow* window = self.window;	// note that this forces the views to be loaded

		_paths = [NSMutableArray new];
		_data = [NSMutableDictionary new];
		
		[__tableView setDoubleAction:@selector(doubleClicked:)];
		[__tableView setTarget:self];
		
		_finder = finder;

		[self showWindow:window];
		[self.window makeKeyAndOrderFront:self];

		[opened addObject:self];
    }
    
    return self;
}

- (void)releaseWindow
{
	// The window will go away when the last reference to its controller
	// goes away.
	[opened removeObject:self];
}

- (void)addPath:(NSAttributedString*)path matches:(NSArray*)matches
{
	[_paths addObject:path];
	_data[path] = matches;
	
	[self->__tableView reloadData];
	[self->__tableView expandItem:path];
}

- (void)resetPath:(RefreshStr)pathBlock andMatchStyles:(RefreshStr)matchBlock
{
	NSMutableArray* newPaths = [NSMutableArray new];
	NSMutableDictionary* newData = [NSMutableDictionary new];
	
	for (NSAttributedString* path in _paths)
	{
		NSAttributedString* newPath = pathBlock(path);
		[newPaths addObject:newPath];

		NSMutableArray* newMatches = [NSMutableArray new];
		for (NSAttributedString* match in _data[path])
		{
			NSAttributedString* newMatch = matchBlock(match);
			[newMatches addObject:newMatch];
		}
		newData[newPath] = newMatches;
	}
	
	_paths = newPaths;
	_data = newData;
	
	_pathHeight = 0.0;
	_matchHeight = 0.0;

	[self->__tableView reloadData];
}

- (void)doubleClicked:(id)sender
{
	UNUSED(sender);
		
	NSArray* selectedItems = [self _getSelectedItems];
	for (NSAttributedString* item in selectedItems)
	{
		PersistentRange* range = [item attribute:@"FindRange" atIndex:0 effectiveRange:NULL];
		if (range)
		{
			// The item is a match line.
			if (range.range.location != NSNotFound)		// happens if the user edits the match
				[OpenFile openPath:range.path withRange:range.range];
		}
		else
		{
			// The item is the path to the file matches were found in.
			if ([self->__tableView isItemExpanded:item])
				[self->__tableView collapseItem:item];
			else
				[self->__tableView expandItem:item];
		}
	}
}

- (CGFloat)outlineView:(NSOutlineView*)table heightOfRowByItem:(id)item
{
	CGFloat* height = _data[item] ? &_pathHeight : &_matchHeight;
	
	if (*height == 0.0)
	{
		NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"1"];
		NSAttributedString* str = [self outlineView:table objectValueForTableColumn:column byItem:item];
		*height = str.size.height;
	}
	
	return *height;
}

- (NSArray*)_getSelectedItems
{
	__block NSMutableArray* result = [NSMutableArray new];
	
	NSIndexSet* indexes = [self->__tableView selectedRowIndexes];
	[indexes enumerateIndexesUsingBlock:
		 ^(NSUInteger index, BOOL* stop)
		 {
			 UNUSED(stop);
			 [result addObject:[self->__tableView itemAtRow:(NSInteger)index]];
		 }];
	
	return result;
}

- (NSInteger)outlineView:(NSOutlineView*)table numberOfChildrenOfItem:(id)item
{
	UNUSED(table);
	
	NSArray* matches = _data[item];
	if (!item)
		return (NSInteger) _paths.count;
	else if (matches)
		return (NSInteger) matches.count;
	else
		return 0;
}

- (BOOL)outlineView:(NSOutlineView*)table isItemExpandable:(id)item
{
	UNUSED(table);
	
	NSArray* matches = _data[item];
	if (!item)
		return YES;
	else if (matches)
		return YES;
	else
		return NO;
}

- (id)outlineView:(NSOutlineView*)table child:(NSInteger)index ofItem:(id)item
{
	UNUSED(table);
	
	NSArray* matches = _data[item];
	if (!item)
		return _paths[(NSUInteger) index];
	else if (matches)
		return matches[(NSUInteger) index];
	else
		return nil;
}

- (id)outlineView:(NSOutlineView*)table objectValueForTableColumn:(NSTableColumn*)column byItem:(id)item
{
	UNUSED(table, column);
	
	return item;
}

@end
