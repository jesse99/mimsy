#import "Utils.h"

#import "Assert.h"
#import "Glob.h"
#import <sys/xattr.h>

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

+ (NSArray*)splitString:(NSString*)str by:(NSString*)separator
{
	NSArray* tmp = [str componentsSeparatedByString:separator];
	
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:tmp.count];
	for (NSString* s in tmp)
	{
		if (s.length > 0)
			[result addObject:s];
	}
	
	return result;
}

+ (NSString*)titleCase:(NSString*)str
{
	NSString* result = str;
	
	if (result.length > 0)
	{
		NSString* prefix = [[str substringToIndex:1] uppercaseString];
		NSString* suffix = [str substringFromIndex:1];
		result = [prefix stringByAppendingString:suffix];
	}
	
	return str;
}

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
	ASSERT(buffer != NULL);
	
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

+ (NSArray*)mapArray:(NSArray*)array block:(id (^)(id element))block
{
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:array.count];
	
	for (id element in array)
	{
		[result addObject:block(element)];
	}
	
	return result;
}

// Based on some Apple sample code floating around the interwebs.
+ (NSString*)pathForTemporaryFileWithPrefix:(NSString*)prefix
{	
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    ASSERT(uuid != NULL);
	
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
    ASSERT(uuidStr != NULL);
	
    NSString* result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", prefix, uuidStr]];
    ASSERT(result != nil);
	
    CFRelease(uuidStr);
    CFRelease(uuid);
	
    return result;
}

+ (void)enumerateDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block
{
	NSFileManager* fm = [NSFileManager new];
	NSArray* candidates = [fm contentsOfDirectoryAtPath:path error:error];
	if (!*error)
	{
		for (NSString* candidate in candidates)
		{
			if (!glob || [glob matchName:candidate])
			{
				NSString* item = [path stringByAppendingPathComponent:candidate];
				block(item);
			}
		}
	}
}

+ (void)writeMetaDataTo:(NSString*)path named:(NSString*)name with:(id<NSCoding>)object
{
	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:object];
	
	int result = setxattr(path.UTF8String, name.UTF8String, data.bytes, data.length, 0, 0);
	if (result < 0)
		LOG_WARN("Mimsy", "Failed writing %s to %s: %s", STR(name), STR(path), strerror(errno));
}

+ (id)readMetaDataFrom:(NSString*)path named:(NSString*)name
{
	ssize_t length = getxattr(path.UTF8String, name.UTF8String, NULL, 64*1024, 0, 0);
	if (length > 0)
	{
		void* buffer = alloca(length);
		ssize_t result = getxattr(path.UTF8String, name.UTF8String, buffer, (size_t)length, 0, 0);
		if (result > 0)
		{
			NSData* data = [NSData dataWithBytes:buffer length:(NSUInteger)length];			
			return [NSKeyedUnarchiver unarchiveObjectWithData:data];
		}
		else
		{
			LOG_WARN("Mimsy", "Failed reading %s from %s: %s", STR(name), STR(path), strerror(errno));
		}
	}
	return nil;
}

@end
