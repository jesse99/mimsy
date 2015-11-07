#if OLD_EXTENSIONS
@protocol ProcFile;

// Used to respond to read/write requests from extensions (and the Finder).
@interface ProcFileSystem : NSObject

- (id)init;

- (void)teardown;

- (void)addReader:(id<ProcFile>)file;
- (void)removeReader:(id<ProcFile>)file;

- (void)addWriter:(id<ProcFile>)file;
- (void)removeWriter:(id<ProcFile>)file;

@end
#endif
