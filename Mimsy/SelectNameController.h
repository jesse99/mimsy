#import <Cocoa/Cocoa.h>

/// Used to select one or more names from a list.
@interface SelectNameController : NSWindowController <NSTableViewDataSource>

- (SelectNameController*)initWithTitle:(NSString*)title names:(NSArray*)names;

/// Set when the OK button is pressed.
@property NSIndexSet* selectedRows;

@property (weak) IBOutlet NSTableView* table;

@end
