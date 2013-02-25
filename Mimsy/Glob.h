#import <Foundation/Foundation.h>

// Used to match file names using a small regex sort of language:
//    * matches zero or more characters
//    ? matches a single character
//    [x] matches the characters in the bracket
//    everything else matches itself
//
// Also see ConditionalGlob.
@interface Glob : NSObject

- (id)initWithGlob:(NSString*)glob;
- (id)initWithGlobs:(NSArray*)globs;

// Returns 1 for match and 0 for no match.
- (int)matchName:(NSString*)name;

@end
