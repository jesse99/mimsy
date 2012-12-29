#import <Foundation/Foundation.h>

@class RegexStyler;

// Loads language files from disk and uses those to map files to RegexStyler instances.
@interface Languages : NSObject

+ (void)setup;

// Attempts to find a styler for the given file name and file contents (some languages
// peek into the file contents to determine if the language is applicable). Returns
// nil if a language was not found.
+ (RegexStyler*)findStylerWithFileName:(NSString*)name contents:(NSString*)text;

@end
