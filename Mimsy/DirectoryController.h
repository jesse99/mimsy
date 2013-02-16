#import <Cocoa/Cocoa.h>

@interface DirectoryController : NSWindowController

- (id)initWithDir:(NSString*)path;

@property (weak) IBOutlet NSOutlineView* table;

@end
