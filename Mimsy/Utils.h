#import <Cocoa/Cocoa.h>

// Misc utility functions.
@interface Utils : NSObject

// Converts bytes to a string like "10 KiB" or "1.2 MiB".
+ (NSString*)bytesToStr:(NSUInteger)bytes precision:(int)precision;

@end
