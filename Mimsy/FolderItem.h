#import "FileSystemItem.h"

@class DirectoryController;

// Class for sub-directories appearing in the directory window outline view.
@interface FolderItem : FileSystemItem

// Overrides
- (id)initWithPath:(NSString*)path controller:(DirectoryController*)controller;
- (bool)isExpandable;
- (NSUInteger)count;
- (NSAttributedString*) name;
- (NSAttributedString*)bytes;
- (FileSystemItem*)objectAtIndexedSubscript:(NSUInteger)index;
- (FileSystemItem*)find:(NSString*)path;
- (bool)reload:(NSMutableArray*)added;

@end
