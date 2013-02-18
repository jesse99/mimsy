#import <Cocoa/Cocoa.h>

// Base class for the items which appear in the directory window outline view.
@interface FileSystemItem : NSObject

- (id)initWithPath:(NSString*)path;

// Note that this should be used instead of Count because it will not force
// all children to be loaded. Defaults to false.
- (bool)isExpandable;

// Defaults to zero.
- (NSUInteger)count;

// Returns "" if the item has no size (mostly directories but possibly for files too).
- (NSString*)bytes;

- (FileSystemItem*)objectAtIndexedSubscript:(NSUInteger)index;

- (NSString*)description;

// This is called whenever a file is added, removed, or modified in any
// directory beneath the root item. Returns true if the item changed.
- (bool)reload:(NSMutableArray*)added;

// Returns the (opened) item which matches the specified path or nil
// if no item was found.
- (FileSystemItem*)find:(NSString*)path;

- (BOOL)isEqual:(id)rhs;
- (NSUInteger)hash;

@property (readonly) NSString* name;
@property (readonly) NSString* path;

@end
