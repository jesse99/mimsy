@interface NSMenu (MenuCategory)

// Just like addItemWithTitle except that the menu is kept sorted
- (NSMenuItem*)addSortedItemWithTitle:(NSString *)title action:(SEL)selector keyEquivalent:(NSString *)charCode;

// Like insertItem except that the item is kept sorted (stopping if a
// separator id reached).
- (void)insertSortedItem:(NSMenuItem *)item atIndex:(NSInteger)index;

// This is normally used when building contextual menus. New items are added via addSortedItemWithTitle.
// root is the proc file path less the /Volumes/Mimsy/ prefix.
// contents is passed to extensions and should be some form of selection.
// If an item added by this method is chosen the extension will be automagically called.
- (void)addExtensionItems:(NSString*)root contents:(NSString*)contents;

@end
