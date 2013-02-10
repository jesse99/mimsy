#import <Cocoa/Cocoa.h>

@class Glob;

extern const NSRange NSZeroRange;

// Misc utility functions.
@interface Utils : NSObject

// Converts bytes to a string like "10 KiB" or "1.2 MiB".
+ (NSString*)bytesToStr:(NSUInteger)bytes;

// Returns a `hexdump -C` sort of string except that unicode symbols are
// used for control characters.
+ (NSString*)bufferToStr:(const void*)buffer length:(NSUInteger)length;

// Reads a file and returns an array containing each line (without the new lines).
+ (NSArray*)readLines:(NSString*)path outError:(NSError**)error;

// This will create destination directories as needed and overwrite the destination
// file if it exists.
+ (bool)copySrcFile:(NSString*)srcPath dstFile:(NSString*)dstPath outError:(NSError**)outError;

// Returns a path to a unique file name in the temporary directory for the current user.
+ (NSString*)pathForTemporaryFileWithPrefix:(NSString *)prefix;

// Iterates over all items in the directory that match the glob. Hidden files are
// returned (except '.' and '..'). If glob is nil all the items are returned.
// The block is called with full paths to each item.
+ (bool)enumerateDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block;

// Just like the above except that sub-directories are searched.
+ (bool)enumerateDeepDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block;

@end
