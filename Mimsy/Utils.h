#import <Cocoa/Cocoa.h>

@class Glob;

extern const time_t NoTimeOut;
extern const time_t MainThreadTimeOut;

bool rangeIntersectsIndex(NSRange range, NSUInteger index);
bool rangeIntersects(NSRange lhs, NSRange rhs);

// Misc utility functions.
@interface Utils : NSObject

// Converts bytes to a string like "10K" or "1.2M". Note that these are the base 10
// units which are the correct units for files but not for memory.
+ (NSString*)bytesToStr:(NSUInteger)bytes;

// Returns a `hexdump -C` sort of string except that unicode symbols are
// used for control characters.
+ (NSString*)bufferToStr:(const void*)buffer length:(NSUInteger)length;

// Reads a file and returns an array containing each line (without the new lines).
+ (NSArray*)readLines:(NSString*)path outError:(NSError**)error;

// This will create destination directories as needed and overwrite the destination
// file if it exists.
+ (bool)copySrcFile:(NSString*)srcPath dstFile:(NSString*)dstPath outError:(NSError**)outError;

// Runs the task returning the exit code. If stdout/stderr is not NULL then those
// are returned as well. Timeout is either NoTimeOut, MainThreadTimeOut, or a time
// in seconds. An error is returned if the process exits with a non-zero return code
// or the process takes longer than timeout seconds to execute.
+ (NSError*)run:(NSTask*)task stdout:(NSString**)stdout stderr:(NSString**)stderr timeout:(time_t)timeout;

// Returns a path to a unique file name in the temporary directory for the current user.
+ (NSString*)pathForTemporaryFileWithPrefix:(NSString *)prefix;

// Iterates over all items in the directory that match the glob. Hidden files are
// returned (except '.' and '..'). If glob is nil all the items are returned.
// The block is called with full paths to each item.
+ (bool)enumerateDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block;

// Just like the above except that sub-directories are searched.
+ (bool)enumerateDeepDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block;

@end
