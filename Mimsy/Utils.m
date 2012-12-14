#import "Utils.h"

@implementation Utils

+ (NSString*)bytesToStr:(NSUInteger)bytes precision:(int)precision
{
	if (bytes > 1024*1024*1024)
		return [[NSString alloc] initWithFormat:@"%.*f GiB", precision, bytes/(1024*1024*1024.0)];
	
	else if (bytes > 1024*1024)
		return [[NSString alloc] initWithFormat:@"%.*f MiB", precision, bytes/(1024*1024.0)];
	
	else if (bytes > 10*1024)
		return [[NSString alloc] initWithFormat:@"%.*f KiB", precision, bytes/1024.0];
	
	else
		return [[NSString alloc] initWithFormat:@"%lu bytes", bytes];
}

@end
