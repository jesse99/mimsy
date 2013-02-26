#import "FileSystemItem.h"

// Class for files appearing in the directory window outline view.
@interface FileItem : FileSystemItem

// Overrides
- (id)initWithPath:(NSString*)path controller:(DirectoryController*)controller;
- (NSAttributedString*) name;
- (NSString*)bytes;
- (bool)reload:(NSMutableArray*)added;

@end
