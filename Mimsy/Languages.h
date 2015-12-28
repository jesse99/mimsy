#import <Foundation/Foundation.h>

@class Language;

/// Loads language files from disk and uses those to map files to RegexStyler instances.
@interface Languages : NSObject

+ (void)setup;

+ (void)languagesChanged;

/// Attempts to find a styler for the given file name and file contents (some languages
/// peek into the file contents to determine if the language is applicable). Returns
/// nil if a language was not found.
+ (Language*)findWithFileName:(NSString*)name contents:(NSString*)text;

/// Returns nil if a language was not found.
+ (Language*)findWithlangName:(NSString*)name;

+ (void)enumerate:(void (^)(Language* lang, bool* stop))block;

+ (NSArray*)languages;

@end
