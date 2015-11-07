#if OLD_EXTENSIONS

// Encapsulates a proc file under the Mimsy mount. Paths are things like "/version".
// Note that the path can be dynamic, e.g. paths associated with text editor proc
// files change with the window ordering.
@protocol ProcFile

- (bool)matchesAnyDirectory:(NSString*)path;
- (bool)matchesFile:(NSString*)path;
- (NSArray*)directChildren:(NSString*)path;	// returns names, not paths

- (unsigned long long)sizeFor:(NSString*)path;
- (bool)setSize:(unsigned long long)size;

- (bool)openPath:(NSString*) path read:(bool)reading write:(bool)writing;
- (void)close;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;
- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

@end
#endif