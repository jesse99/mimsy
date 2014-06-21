#import <Cocoa/Cocoa.h>

@class FindInFiles;

typedef NSAttributedString* (^RefreshStr)(NSAttributedString*);

// Controller for the window used to show the results of find all.
@interface FindResultsController : NSWindowController

+ (FindResultsController*)frontmost;

- (id)initWith:(FindInFiles*)finder;
- (void)releaseWindow;

- (void)addPath:(NSAttributedString*)path matches:(NSArray*)matches;
- (void)resetPath:(RefreshStr)pathBlock andMatchStyles:(RefreshStr)matchBlock;

- (void)doubleClicked:(id)sender;

- (void)openNext;
- (bool)canOpenNext;

- (void)openPrevious;
- (bool)canOpenPrevious;

@property (strong) IBOutlet NSOutlineView *_tableView;

@end
