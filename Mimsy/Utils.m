#import "Utils.h"

const NSRange NSZeroRange = {0};

// These are more technically correct but the new-line and tab symbols are really hard
// to read unless the font's point size is very large.
//    static NSString* NewLineSymbol = @"\u2424";
//    static NSString* ReturnSymbol = @"\u23CE";
//    static NSString* TabSymbol = @"\u2409";

static NSString* RightArrow = @"\u2192";
static NSString* DownArrow = @"\u2193";
static NSString* DownHookedArrow = @"\u21A9";
static NSString* Replacement = @"\uFFFD";

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

+ (NSString*)bufferToStr:(const void*)buffer length:(NSUInteger)length
{
	NSAssert(buffer != NULL, @"buffer was NULL");
	
	NSMutableString* result = [NSMutableString new];
	const unsigned char* data = (const unsigned char*) buffer;
	
	NSUInteger i = 0;
	while (i < length)
	{
		// Offset
		[result appendFormat:@"%.8lX", i];
		
		// Byte values
		for (NSUInteger d = 0; d < 16 && i + d < length; ++d)
		{
			[result appendFormat:@"%.2X", data[i + d]];
			if (d == 7)
				[result appendString:@"\t"];
		}
		
		// Char values
		[result appendString:@"\t"];
		for (NSUInteger d = 0; d < 16 && i + d < length; ++d)
		{
			if (data[i + d] == '\n')
				[result appendString:DownArrow];
			
			else if (data[i + d] == '\r')
				[result appendString:DownHookedArrow];
			
			else if (data[i + d] == '\t')
				[result appendString:RightArrow];
			
			else if (data[i + d] < 0x20 || data[i + d] >= 0x7f)
				[result appendString:Replacement];
			
			else
				[result appendFormat:@"%c", (char) data[i + d]];
			
			if (d == 7)
				[result appendString:@"   "];
		}
		
		i += 16;
		[result appendString:@"\n"];
	}
	
	return result;
}

// Based on some Apple sample code floating around the interwebs.
+ (NSString*)pathForTemporaryFileWithPrefix:(NSString*)prefix
{	
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);
	
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
    assert(uuidStr != NULL);
	
    NSString* result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", prefix, uuidStr]];
    assert(result != nil);
	
    CFRelease(uuidStr);
    CFRelease(uuid);
	
    return result;
}

@end