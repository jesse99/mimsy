#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

/// Misc methods related to the paths used by Mimsy to locate various files.
@interface Paths : NSObject

/// Path to a caches directory. Useful for large files that should not be
/// backed up by Time Machine. Returns nil on errors.
+ (NSString*)caches;

/// Path to a directory of (dynamically) installed files in the current
/// user's home directory, e.g. "languages". Name may be nil.
+ (MimsyPath*)installedDir:(NSString*)name;

@end
