#import <Cocoa/Cocoa.h>

@class Glob;

extern const NSRange NSZeroRange;

// Misc utility functions.
@interface Utils : NSObject

// Like componentsSeparatedByString: except that empty strings are not returned.
+ (NSArray*)splitString:(NSString*)str by:(NSString*)separator;

// Like componentsSeparatedByString: except that empty strings are not returned.
+ (NSArray*)splitChars:(NSString*)str by:(NSCharacterSet*)chars;

// Capitilizes the first character in the string.
+ (NSString*)titleCase:(NSString*)str;

// Converts bytes to a string like "10 KiB" or "1.2 MiB".
+ (NSString*)bytesToStr:(NSUInteger)bytes;

// Returns a `hexdump -C` sort of string except that unicode symbols are
// used for control characters.
+ (NSString*)bufferToStr:(const void*)buffer length:(NSUInteger)length;

// Reads a file and returns an array containing each line (without the new lines).
+ (NSArray*)readLines:(NSString*)path outError:(NSError**)error;

// Returns a path to a unique file name in the temporary directory for the current user.
+ (NSString*)pathForTemporaryFileWithPrefix:(NSString *)prefix;

// Iterates over all items in the directory that match the glob. Hidden files are
// returned (except '.' and '..'). If glob is nil all the items are returned.
// The block is called with full paths to each item.
+ (void)enumerateDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block;

// Just like the above except that sub-directories are searched.
+ (void)enumerateDeepDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block;

@end
