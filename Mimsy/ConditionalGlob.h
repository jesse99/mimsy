#import "Glob.h"

// Like Glob except that it also checks to see if the file contents match
// at least one regex.
@interface ConditionalGlob : Glob

- (id)initWithGlob:(NSString*)glob;
- (id)initWithGlobs:(NSArray*)globs;
- (id)initWithGlobs:(NSArray*)globs regexen:(NSArray*)regexen conditionals:(NSArray*)conditionals;

- (bool)matchName:(NSString*)name contents:(NSString*)contents;

@end
