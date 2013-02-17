#import "FileSystemItem.h"

// Class for sub-directories appearing in the directory window outline view.
@interface FolderItem : FileSystemItem

// Overrides
- (id)initWithPath:(NSString*)path;
- (bool)isExpandable;
- (NSUInteger)count;
- (FileSystemItem*)objectAtIndexedSubscript:(NSUInteger)index;
- (bool)reload:(NSMutableArray*)added;

@end
