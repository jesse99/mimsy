#import <Foundation/Foundation.h>

@interface NSString (StringCategory)

// Like componentsSeparatedByString: except that empty strings are not returned.
- (NSArray*)splitByString:(NSString*)separator;

// Like componentsSeparatedByString: except that empty strings are not returned.
- (NSArray*)splitByChars:(NSCharacterSet*)chars;

// Capitilizes the first character in the string.
- (NSString*)titleCase;

// Returns a new string with each character mapped using the block.
- (NSString*)map:(unichar (^)(unichar ch))block;

@end
