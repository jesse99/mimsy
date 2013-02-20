#import <Cocoa/Cocoa.h>

@class Glob;

// This is the controller for the windows which display the contents of a directory.
// These windows work a bit like project windows in IDEs.
@interface DirectoryController : NSWindowController

- (id)initWithDir:(NSString*)path;

@property Glob* ignores;
@property (weak) IBOutlet NSOutlineView* table;

@end
