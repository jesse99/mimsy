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

bool rangeIntersectsIndex(NSRange range, NSUInteger index)
{
	return rangeIntersects(range, NSMakeRange(index, 1));
}

bool rangeIntersects(NSRange lhs, NSRange rhs)
{
	bool intersects = false;
	
	if (lhs.length > 0 && rhs.length > 0)
	{
		if (rhs.location < lhs.location)
			intersects = rhs.location + rhs.length > lhs.location;
		
		else if (rhs.location > lhs.location)
			intersects = lhs.location + lhs.length > rhs.location;
		
		else
			intersects = true;
	}
	
	return intersects;
}

@implementation Utils

+ (NSString*)bytesToStr:(NSUInteger)bytes
{
	if (bytes > 1000*1000*1000)
		return [[NSString alloc] initWithFormat:@"%.2fG", bytes/(1000*1000*1000.0)];
	
	else if (bytes > 1000*1000)
		return [[NSString alloc] initWithFormat:@"%.1fM", bytes/(1000*1000.0)];
	
	else if (bytes > 1000)
		return [[NSString alloc] initWithFormat:@"%.1fK", bytes/1000.0];
	
	else
		return [[NSString alloc] initWithFormat:@"%lu", bytes];
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

+ (bool)enumerateDir:(NSString*)path glob:(Glob*)glob error:(NSError**)error block:(void (^)(NSString* item))block
{
	NSFileManager* fm = [NSFileManager new];
	NSArray* candidates = [fm contentsOfDirectoryAtPath:path error:error];
	if (candidates)
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
	return candidates;
}

+ (bool)enumerateDeepDir:(NSString*)path glob:(Glob*)glob error:(NSError**)outError block:(void (^)(NSString* item))block
{	
	NSFileManager* fm = [NSFileManager new];
	NSMutableArray* errors = [NSMutableArray new];
	
	NSURL* at = [NSURL fileURLWithPath:path isDirectory:YES];
	NSArray* keys = @[NSURLNameKey, NSURLIsDirectoryKey, NSURLPathKey];
	NSDirectoryEnumerationOptions options = glob ? NSDirectoryEnumerationSkipsHiddenFiles : 0;
	NSDirectoryEnumerator* enumerator = [fm enumeratorAtURL:at includingPropertiesForKeys:keys options:options errorHandler:
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
		BOOL populated = [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];

		if (populated && !isDirectory.boolValue)		// note that NSDirectoryEnumerationSkipsHiddenFiles also skips hidden directories
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
	
	if (errors.count && outError)
	{
		NSString* mesg = [errors componentsJoinedByString:@"\n"];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*outError = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
	}
	return errors.count == 0;
}

+ (bool)copySrcFile:(NSString*)srcPath dstFile:(NSString*)dstPath outError:(NSError**)outError
{
	NSError* error = nil;
	NSFileManager* fm = [NSFileManager defaultManager];
	
	if ([fm fileExistsAtPath:dstPath] && ![fm removeItemAtPath:dstPath error:&error])
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to remove old '%@': %@", dstPath, reason];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*outError = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
		return false;
	}
	
	NSString* dstDir = [dstPath stringByDeletingLastPathComponent];
	if (![fm createDirectoryAtPath:dstDir withIntermediateDirectories:YES attributes:nil error:&error])
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to create directories for '%@': %@", dstPath, reason];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*outError = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
		return false;
	}
	
	if (![fm copyItemAtPath:srcPath toPath:dstPath error:&error])
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to copy '%@' to '%@': %@", srcPath, dstPath, reason];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*outError = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
		return false;
	}
	
	return true;
}

+ (int)run:(NSTask*)task stdout:(NSString**)stdout stderr:(NSString**)stderr
{
	// TODO: NSTask can block if the pipes get full, may want to try: http://dev.notoptimal.net/2007/04/nstasks-nspipes-and-deadlocks-when.html
	[task launch];
	
	if (stdout)
	{
		NSData* data = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
		*stdout = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	if (stderr)
	{
		NSData* data = [[[task standardError] fileHandleForReading] readDataToEndOfFile];
		*stderr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	[task waitUntilExit];
	
	return task.terminationStatus;
}

@end
