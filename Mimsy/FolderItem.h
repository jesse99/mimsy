#import "FileSystemItem.h"

@class DirectoryController;

/// Class for sub-directories appearing in the directory window outline view.
@interface FolderItem : FileSystemItem

// Overrides
- (id)initWithPath:(MimsyPath*)path controller:(DirectoryController*)controller;
- (bool)isExpandable;
- (NSUInteger)count;
- (NSAttributedString*) name;
- (NSAttributedString*)bytes;
- (FileSystemItem*)objectAtIndexedSubscript:(NSUInteger)index;
- (FileSystemItem*)find:(MimsyPath*)path;
- (bool)reload:(NSMutableArray*)added;

@end
