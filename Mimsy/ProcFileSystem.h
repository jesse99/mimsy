@protocol ProcFile;

// Used to respond to read/write requests from extensions (and the Finder).
@interface ProcFileSystem : NSObject

- (id)init;

- (void)teardown;

- (void)add:(id<ProcFile>)file;
- (void)remove:(id<ProcFile>)file;

@end
