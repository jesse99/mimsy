#import <Foundation/Foundation.h>

// The view displaying the tree view of files and directories within an opened
// directory.
@interface FindResultsView : NSOutlineView

- (void)keyDown:(NSEvent*)event;

@end
