#import "MenuCategory.h"

@implementation NSMenu (MenuCategory)

- (NSMenuItem *)addSortedItemWithTitle:(NSString *)title action:(SEL)selector keyEquivalent:(NSString *)charCode
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

- (void) insertSortedItem:(NSMenuItem *)newItem atIndex:(NSInteger)index
{
    for (NSInteger i = index; i < self.numberOfItems; ++i)
    {
        NSMenuItem* item = [self itemAtIndex:i];
        if (item.isSeparatorItem || [item.title compare:newItem.title] != NSOrderedAscending)
        {
            [self insertItem:newItem atIndex:i];
            return;
        }
    }
    
    [self insertItem:newItem atIndex:self.numberOfItems];
}


@end
