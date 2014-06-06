#import <Cocoa/Cocoa.h>

@class FindInFiles;

// Controller for the window used to show the results of find all.
@interface FindResultsController : NSWindowController

- (id)initWith:(FindInFiles*)finder;
- (void)releaseWindow;

- (void)addPath:(NSAttributedString*)path matches:(NSArray*)matches;
- (void)doubleClicked:(id)sender;

@property (strong) IBOutlet NSOutlineView *_tableView;

@end
