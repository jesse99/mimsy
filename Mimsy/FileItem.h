#import "FileSystemItem.h"

// Class for files appearing in the directory window outline view.
@interface FileItem : FileSystemItem

// Overrides
- (id)initWithPath:(NSString*)path;
- (NSString*)bytes;

@end
