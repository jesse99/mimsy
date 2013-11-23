#import <Cocoa/Cocoa.h>

@class DirectoryController;

@interface BuildOptionsController : NSWindowController <NSTableViewDataSource>

- (BuildOptionsController*) init;
- (void) openWith:(DirectoryController*)controller;

- (IBAction)okPressed:(id)sender;
- (IBAction)cancelPressed:(id)sender;

@property (weak) IBOutlet NSTableView *table;
@property IBOutlet NSMutableArray *targets;
@property IBOutlet NSMutableArray *flags;

@end
