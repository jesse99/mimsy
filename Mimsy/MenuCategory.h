@interface NSMenu (MenuCategory)

/// Just like addItemWithTitle except that the menu is kept sorted
- (NSMenuItem*)addSortedItemWithTitle:(NSString *)title action:(SEL)selector keyEquivalent:(NSString *)charCode;

/// Like insertItem except that the item is kept sorted (stopping if a
/// separator id reached).
- (void)insertSortedItem:(NSMenuItem *)item atIndex:(NSInteger)index;

- (void)appendSortedItem:(NSMenuItem *)item;

@end
