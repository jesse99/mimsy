#import <Foundation/Foundation.h>

// Used to select a Styles.rtf file to use for syntax highlighting and to
// rate the existing styles files.
@interface SetStyleController : NSWindowController <NSTableViewDataSource>

+ (SetStyleController*)open;

- (IBAction)setDefault:(id)sender;

@property (weak) IBOutlet NSTableView *table;
@property (weak) IBOutlet NSButton *makeDefaultButton;

- (NSInteger)numberOfRowsInTableView:(NSTableView* )view;
- (id)tableView:(NSTableView* )view objectValueForTableColumn:(NSTableColumn*)column row:(NSInteger)row;
- (void)tableView:(NSTableView*)view setObjectValue:(id)object forTableColumn:(NSTableColumn*)column row:(NSInteger)row;

@end
