#import "ProcFile.h"

// Proc file for use by read-only files that will not be very large.
@interface ProcFileReader : NSObject <ProcFile>

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name readStr:(NSString* (^)())readStr;

- (bool)matchesAnyDirectory:(NSString*)path;
- (bool)matchesFile:(NSString*)path;
- (NSArray*)directChildren:(NSString*)path;

- (unsigned long long)sizeFor:(NSString*)path;

- (bool)setSize:(unsigned long long)size;
- (bool)openPath:(NSString*) path read:(bool)reading write:(bool)writing;
- (void)close;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;
- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

- (void)notifyIfChangedBlocking;
- (void)notifyIfChangedNonBlocking;

@end

// Proc file for use by read-write files that will not be very large.
@interface ProcFileReadWrite : NSObject <ProcFile>

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name readStr:(NSString* (^)())readStr writeStr:(void (^)(NSString*))writeStr;

- (bool)matchesAnyDirectory:(NSString*)path;
- (bool)matchesFile:(NSString*)path;
- (NSArray*)directChildren:(NSString*)path;	

- (unsigned long long)sizeFor:(NSString*)path;
- (bool)setSize:(unsigned long long)size;

- (bool)openPath:(NSString*) path read:(bool)reading write:(bool)writing;
- (void)close;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;
- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

- (void)notifyIfChangedBlocking;
- (void)notifyIfChangedNonBlocking; 

@end

typedef NSArray* (^KeysBlock)();
typedef NSString* (^ValueBlock)(NSString*);

// Proc file used to return read-only values by key.
@interface ProcFileKeyStoreR : NSObject <ProcFile>

- (id)initWithDir:(NSString* (^) ())directory keys:(KeysBlock)keys values:(ValueBlock)values;

- (bool)matchesAnyDirectory:(NSString*)path;
- (bool)matchesFile:(NSString*)path;
- (NSArray*)directChildren:(NSString*)path;

- (unsigned long long)sizeFor:(NSString*)path;
- (bool)setSize:(unsigned long long)size;

- (bool)openPath:(NSString*) path read:(bool)reading write:(bool)writing;
- (void)close;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;
- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

@end

// Proc file used to store arbitrary extension state.
@interface ProcFileKeyStoreRW : NSObject <ProcFile>

- (id)initWithDir:(NSString* (^) ())directory;

- (bool)matchesAnyDirectory:(NSString*)path;
- (bool)matchesFile:(NSString*)path;
- (NSArray*)directChildren:(NSString*)path;

- (unsigned long long)sizeFor:(NSString*)path;
- (bool)setSize:(unsigned long long)size;

- (bool)openPath:(NSString*) path read:(bool)reading write:(bool)writing;
- (void)close;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;
- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

@end

// Args and result are arrays of NSString.
typedef NSArray* (^ProcAction)(NSArray* args);

// Proc file used to execute arbitrary commands.
@interface ProcFileAction : NSObject <ProcFile>

- (id)initWithDir:(NSString* (^) ())directory handler:(ProcAction)handler;

- (bool)matchesAnyDirectory:(NSString*)path;
- (bool)matchesFile:(NSString*)path;
- (NSArray*)directChildren:(NSString*)path;

- (unsigned long long)sizeFor:(NSString*)path;
- (bool)setSize:(unsigned long long)size;

- (bool)openPath:(NSString*) path read:(bool)reading write:(bool)writing;
- (void)close;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;
- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

@end
