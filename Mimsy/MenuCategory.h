@interface NSMenu (MenuCategory)

// Just like addItemWithTitle except that the menu is kept sorted
- (NSMenuItem *)addSortedItemWithTitle:(NSString *)title action:(SEL)selector keyEquivalent:(NSString *)charCode;

@end
