#import <Cocoa/Cocoa.h>

@class Glob;

extern const NSRange NSZeroRange;

// Misc utility functions.
@interface Utils : NSObject

// Like componentsSeparatedByString: except that empty strings are not returned.
+ (NSArray*)splitString:(NSString*)str by:(NSString*)separator;

// Capitilizes the first character in the string.
+ (NSString*)titleCase:(NSString*)str;

// Converts bytes to a string like "10 KiB" or "1.2 MiB".
+ (NSString*)bytesToStr:(NSUInteger)bytes;

// Returns a `hexdump -C` sort of string except that unicode symbols are
// used for control characters.
+ (NSString*)bufferToStr:(const void*)buffer length:(NSUInteger)length;

// Returns a new array with each element mapped using the block.
+ (NSArray*)mapArray:(NSArray*)array block:(id (^)(id element))block;

// Returns a path to a unique file name in the temporary directory for the current user.
+ (NSString*)pathForTemporaryFileWithPrefix:(NSString *)prefix;

// Iterates over all items in the directory that match the glob. Hidden files are
// returned (except '.' and '..'). If glob is nil all the items are returned.
// Note that this does not enumerate sub-directories.
+ (void)enumerateDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block;

@end
