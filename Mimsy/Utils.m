#import "Utils.h"

#import "Assert.h"
#import "Glob.h"

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

+ (NSArray*)readLines:(NSString*)path outError:(NSError**)error
{
	NSArray* result = nil;
	
	NSString* contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
	if (!*error)
		result = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	
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

+ (void)enumerateDeepDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block
{
	NSFileManager* fm = [NSFileManager new];
	NSMutableArray* errors = [NSMutableArray new];
	
	NSURL* at = [NSURL fileURLWithPath:path isDirectory:YES];
	NSArray* keys = @[NSURLNameKey, NSURLIsDirectoryKey, NSURLPathKey];
	NSDirectoryEnumerator* enumerator = [fm enumeratorAtURL:at includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:
			^BOOL(NSURL* url, NSError* error)
			{
				NSString* reason = [error localizedFailureReason];
				NSString* mesg = [NSString stringWithFormat:@"Couldn't process %s: %s", STR(url), STR(reason)];
				[errors addObject:mesg];

				return YES;
			}
	];
	
	for (NSURL* url in enumerator)
	{		
		NSNumber* isDirectory;
		NSError* error = nil;
		[url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];

		if (!error && !isDirectory.boolValue)		// note that NSDirectoryEnumerationSkipsHiddenFiles also skips hidden directories
		{
			NSString* candidate = url.path;
			if (!glob || [glob matchName:candidate])
				block(candidate);
		}
		else if (error)
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Couldn't check for is directory for %s: %s", STR(url), STR(reason)];
			[errors addObject:mesg];
		}
	}
	
	if (errors.count)
	{
		NSString* mesg = [errors componentsJoinedByString:@"\n"];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
	}
}

@end
