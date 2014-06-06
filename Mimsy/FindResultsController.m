#import "FindResultsController.h"

#import "Assert.h"
#import "FindInFiles.h"
#import "OpenFile.h"

static NSMutableArray* opened;

@implementation FindResultsController
{
	FindInFiles* _finder;			// retain a reference to keep the finder alive
	NSMutableArray* _paths;
	NSMutableDictionary* _data;		// path => matches
	CGFloat _leading;
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
		_leading = 4.0;

		[self showWindow:window];
		[self.window makeKeyAndOrderFront:self];

		[opened addObject:self];
    }
    
    return self;
}

- (void)setLeading:(CGFloat)leading
{
	_leading = leading;
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
	[_data setObject:matches forKey:path];
	
	[self->__tableView reloadData];
	[self->__tableView expandItem:path];
}

- (void)doubleClicked:(id)sender
{
	UNUSED(sender);
		
	NSArray* selectedItems = [self _getSelectedItems];
	for (NSAttributedString* item in selectedItems)
	{
		NSString* path = [item attribute:@"FindPath" atIndex:0 effectiveRange:NULL];
		NSNumber* loc = [item attribute:@"FindLocation" atIndex:0 effectiveRange:NULL];
		if (loc)
		{
			// The item is a match line.
			NSNumber* length = [item attribute:@"FindLength" atIndex:0 effectiveRange:NULL];
			ASSERT(length);

			NSRange range = NSMakeRange(loc.unsignedIntegerValue, length.unsignedIntegerValue);
			[OpenFile openPath:path withRange:range];
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
	NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier:@"1"];
	CGFloat height = [self _getItemHeight:table col:col item:item];
	return height;
}

- (CGFloat)_getItemHeight:(NSOutlineView*)table col:(NSTableColumn*)column item:(id)item
{
	__block CGFloat size = 0.0;
	
	NSAttributedString* str = [self outlineView:table objectValueForTableColumn:column byItem:item];
		[str enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, str.length) options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:
		 ^(NSFont* font, NSRange range, BOOL *stop)
		 {
			 UNUSED(range, stop);
			 
			 size = MAX(font.pointSize, size);
		 }];
	
	
	// Couldn't get decent results with just using NSFont state so we use this
	// lame _leading setting.
	return size + _leading;
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
