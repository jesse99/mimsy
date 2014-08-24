// Used to respond to read/write requests from extensions (and the Finder).
@interface ProcFiles : NSObject

- (id)init;

- (void)teardown;

@end
