#import "ProcFile.h"

// Proc file for use by read-only files that will not be very large.
@interface ProcFileReader : NSObject <ProcFile>

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name readStr:(NSString* (^)())readStr;

- (NSString*)path;
- (unsigned long long)size;
- (bool)setSize:(unsigned long long)size;
- (void)closed;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

@end

// Proc file for use by write-only files that will not be very large.
@interface ProcFileWriter : NSObject <ProcFile>

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name writeStr:(void (^)(NSString*))writeStr;

- (NSString*)path;
- (unsigned long long)size;
- (bool)setSize:(unsigned long long)size;
- (void)closed;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

@end
