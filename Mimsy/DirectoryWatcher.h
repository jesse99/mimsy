#import <Foundation/Foundation.h>

typedef void (^DirectoryWatcherCallback)(NSArray* paths);

// Used to call a block when files are added, removed, or changed from a
// directory and its sub-directories.
@interface DirectoryWatcher : NSObject

// Latency is the number of seconds to wait before calling the block (to allow
// multiple changes to be coalesced). Block will be called with absolute paths
// to the directories with changes.
- (id)initWithPath:(NSString*)path latency:(double)latency block:(DirectoryWatcherCallback)block;

@property (readonly) DirectoryWatcherCallback callback;

@end
