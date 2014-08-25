#import "ProcFile.h"

// Proc file for use by read-only files that will not be very large.
@interface ProcFileReader : NSObject <ProcFile>

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name contents:(NSString* (^)())contents;

- (NSString*)path;
- (unsigned long long)size;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

@end

// Proc file for use by write-only files that will not be very large.
@interface ProcFileWriter : NSObject <ProcFile>

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name contents:(void (^)(NSString*))contents;

- (NSString*)path;
- (unsigned long long)size;

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error;

@end
