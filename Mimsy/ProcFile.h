// Encapsulates a proc file under the Mimsy mount.
@protocol ProcFile

// Should be a path like "/version". Note that the path can be dynamic, e.g.
// paths associated with text editor proc files change with the window ordering.
- (NSString*)path;

- (unsigned long long)size;
- (bool)setSize:(unsigned long long)size;

- (bool)openForRead:(bool)reading write:(bool)writing;
- (void)close;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;
- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

@end
