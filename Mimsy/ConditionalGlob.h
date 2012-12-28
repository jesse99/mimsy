#import "Glob.h"

// Like Glob except that it can also check to see if the file contents match
// at least one regex.
@interface ConditionalGlob : Glob

- (id)initWithGlob:(NSString*)glob;
- (id)initWithGlobs:(NSArray*)globs;
- (id)initWithGlobs:(NSArray*)globs regexen:(NSArray*)regexen conditionals:(NSArray*)conditionals;

// Returns 2 if contents matched, 1 if just a glob matched, and 0 for no match.
- (int)matchName:(NSString*)name contents:(NSString*)contents;

@end
