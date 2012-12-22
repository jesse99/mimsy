#import <Foundation/Foundation.h>

// Misc methods related to the paths used by Mimsy to locate various files.
@interface Paths : NSObject

// Path to a caches directory. Useful for large files that should not be
// backed up by Time Machine. Returns nil on errors.
+ (NSString*)caches;

@end
