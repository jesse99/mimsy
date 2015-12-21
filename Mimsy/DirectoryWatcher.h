#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

// Flags are set as follows:
//    create - kFSEventStreamEventFlagItemCreated
//    remove - kFSEventStreamEventFlagItemRemoved (unless the Finder does it in which case all you will get is rename)
//    rename - kFSEventStreamEventFlagItemRenamed
//    edit   - kFSEventStreamEventFlagItemModified
// If it is a file kFSEventStreamEventFlagItemIsFile is set. If it is a directory kFSEventStreamEventFlagItemIsDir is set.
typedef void (^DirectoryWatcherCallback)(MimsyPath* path, FSEventStreamEventFlags flags);

// Used to call a block when files are added, removed, or changed from a
// directory and its sub-directories.
@interface DirectoryWatcher : NSObject

// Latency is the number of seconds to wait before calling the block (to allow
// multiple changes to be coalesced). Block will be called with absolute paths
// to the directories with changes.
- (id)initWithPath:(MimsyPath*)path latency:(double)latency block:(DirectoryWatcherCallback)block;

@property (readonly) DirectoryWatcherCallback callback;

@end
