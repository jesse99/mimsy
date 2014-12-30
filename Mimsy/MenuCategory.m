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

@end
