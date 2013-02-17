#import <Cocoa/Cocoa.h>

// This is the controller for the windows which display the contents of a directory.
// These windows work a bit like project windows in IDEs.
@interface DirectoryController : NSWindowController

- (id)initWithDir:(NSString*)path;

@property (weak) IBOutlet NSOutlineView* table;

@end
