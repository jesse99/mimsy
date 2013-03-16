#import <Foundation/Foundation.h>

// Provides access to the builder executable installed in the builders directory.
@interface Builders : NSObject

// If a builder can be found for a file in dir then the dictionary includes:
//    "name": the builder name (e.g. "make")
//    "path": full path to the associated build file
// Otherwise nil is returned.
+ (NSDictionary*)builderInfo:(NSString*)dir;

// Returns an array of strings for each target in the build file.
// Info should be the result from findBuilder. Returns nil on failure.
+ (NSArray*)getTargets:(NSDictionary*)info env:(NSDictionary*)vars;

// Returns a dictionary with:
//    "command": the command to execute to build the target (along with an arbitrary set of command line flags)
//    "cwd": full path to the directory in which the command should be executed
+ (NSDictionary*)build:(NSDictionary*)info target:(NSString*)target flags:(NSString*)flags env:(NSDictionary*)vars;

@end
