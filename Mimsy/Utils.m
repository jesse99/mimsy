#import "Utils.h"

@implementation Utils

+ (NSString*)bytesToStr:(NSUInteger)bytes
{
	if (bytes > 1024*1024*1024)
		return [[NSString alloc] initWithFormat:@"%.2f GiB", bytes/(1024*1024*1024.0)];
	
	else if (bytes > 1024*1024)
		return [[NSString alloc] initWithFormat:@"%.1f MiB", bytes/(1024*1024.0)];
	
	else if (bytes > 10*1024)
		return [[NSString alloc] initWithFormat:@"%.0f KiB", bytes/1024.0];
	
	else
		return [[NSString alloc] initWithFormat:@"%lu bytes", bytes];
}

//+ (NSString*)bufferToStr:(const void*)buffer length:(NSUInteger)length
//{
//
//}

@end
