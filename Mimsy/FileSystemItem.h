#import <Cocoa/Cocoa.h>
#import "MimsyPlugins.h"

@class DirectoryController;

/// Base class for the items which appear in the directory window outline view.
@interface FileSystemItem : NSObject

- (id)initWithPath:(MimsyPath*)path controller:(DirectoryController*)controller;

/// Note that this should be used instead of Count because it will not force
/// all children to be loaded. Defaults to false.
- (bool)isExpandable;

/// Defaults to zero.
- (NSUInteger)count;

- (NSAttributedString*) name;

/// Returns "" if the item has no size (mostly directories but possibly for files too).
- (NSAttributedString*)bytes;

- (FileSystemItem*)objectAtIndexedSubscript:(NSUInteger)index;

- (NSString*)description;

/// This is called whenever a file is added, removed, or modified in any
/// directory beneath the root item. Returns true if the item changed.
- (bool)reload:(NSMutableArray*)added;

/// Returns the (opened) item which matches the specified path or nil
/// if no item was found.
- (FileSystemItem*)find:(MimsyPath*)path;

- (BOOL)isEqual:(id)rhs;
- (NSUInteger)hash;

@property (readonly, weak) DirectoryController* controller;
@property (readonly) MimsyPath* path;

@end
