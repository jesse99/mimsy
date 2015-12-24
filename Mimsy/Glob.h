#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

/// Used to match file names using a small regex sort of language:
///    * matches zero or more characters
///    ? matches a single character
///    [x] matches the characters between the brackets
///    everything else matches itself
///
/// Also see ConditionalGlob.
@interface Glob : NSObject <NSCopying, MimsyGlob>

- (id)initWithGlob:(NSString*)glob;
- (id)initWithGlobs:(NSArray*)globs;

/// Returns 1 for match and 0 for no match.
- (int)matchName:(NSString*)name;
- (int)matchStr:(const char*)name;

- (id)copyWithZone:(NSZone*)zone;
- (NSUInteger)hash;
- (BOOL)isEqual:(id)anObject;

- (NSString*)description;

@property (readonly) NSArray* globs;

@end
