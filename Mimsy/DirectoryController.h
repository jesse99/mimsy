#import <Cocoa/Cocoa.h>

@class Glob;

// This is the controller for the windows which display the contents of a directory.
// These windows work a bit like project windows in IDEs.
@interface DirectoryController : NSWindowController

+ (DirectoryController*)getController:(NSString*)path;

- (id)initWithDir:(NSString*)path;

- (bool)shouldOpen:(NSString*)path;
- (void)doubleClicked:(id)sender;

- (NSDictionary*)getDirAttrs:(NSString*)path;
- (NSDictionary*)getFileAttrs:(NSString*)path;
- (NSDictionary*)getSizeAttrs;

@property Glob* ignores;
@property (weak) IBOutlet NSOutlineView* table;

@end
