#import <Cocoa/Cocoa.h>

@class FindInFiles;

// Controller for the window used to show the results of find all.
@interface FindResultsController : NSWindowController

- (id)initWith:(FindInFiles*)finder;

@end
