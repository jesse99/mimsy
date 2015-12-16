#import "MenuCategory.h"

#import "AppDelegate.h"

@implementation NSMenu (MenuCategory)

- (NSMenuItem*)addSortedItemWithTitle:(NSString*)title action:(SEL)selector keyEquivalent:(NSString*)charCode
{
    for (NSInteger i = 0; i < self.numberOfItems; ++i)
    {
        NSMenuItem* item = [self itemAtIndex:i];
        if ([item.title compare:title] != NSOrderedAscending)
        {
            item = [self insertItemWithTitle:title action:selector keyEquivalent:charCode atIndex:i];
            return item;
        }
    }
    
    return [self addItemWithTitle:title action:selector keyEquivalent:charCode];
}

- (void)insertSortedItem:(NSMenuItem*)newItem atIndex:(NSInteger)index
{
    NSMenuItem* item = [self itemAtIndex:index];
    if ([item.title compare:newItem.title] == NSOrderedAscending)
        [self _insertItemAfter:newItem at:index];
    else
        [self _insertItemBefore:newItem at:index];
}

- (void)appendSortedItem:(NSMenuItem*)newItem
{
    if (self.numberOfItems == 0)
    {
        [self addItem:newItem];
    }
    else
    {
        [self insertSortedItem:newItem atIndex:self.numberOfItems-1];
    }
}

- (void)_insertItemAfter:(NSMenuItem*)newItem at:(NSInteger)i
{
    while (true)
    {
        NSMenuItem* item = [self itemAtIndex:i];
        if (item.isSeparatorItem)
        {
            [self insertItem:newItem atIndex:i];
            break;
        }
        else if ([item.title compare:newItem.title] == NSOrderedDescending)
        {
            [self insertItem:newItem atIndex:i];
            break;
        }
        else if (i == self.numberOfItems-1)
        {
            [self insertItem:newItem atIndex:i+1];
            break;
        }
        i += 1;
    }
}

- (void)_insertItemBefore:(NSMenuItem*)newItem at:(NSInteger)i
{
    while (true)
    {
        NSMenuItem* item = [self itemAtIndex:i];
        if (item.isSeparatorItem)
        {
            [self insertItem:newItem atIndex:i+1];
            break;
        }
        else if (i == 0)
        {
            [self insertItem:newItem atIndex:i];
            break;
        }
        else if ([item.title compare:newItem.title] == NSOrderedAscending)
        {
            [self insertItem:newItem atIndex:i+1];
            break;
        }
        i -= 1;
    }
}

@end
