#import "Metadata.h"

#import "Assert.h"
#import "Logger.h"
#import <sys/xattr.h>

@implementation Metadata

+ (NSString*)criticalPath:(NSString*)path named:(NSString*)name outError:(NSError**)error
{
	ASSERT(error != NULL);
	NSString* fpath = nil;

	BOOL isDir;
	NSFileManager* fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:path isDirectory:&isDir])
	{
		if (isDir)
		{
			NSString* fname = [NSString stringWithFormat:@".%@.xml", name];
			fpath = [path stringByAppendingPathComponent:fname];
		}
		else
		{
			NSString* fname = [NSString stringWithFormat:@".%@-%@.xml", path.lastPathComponent.stringByDeletingPathExtension, name];
			path = [path stringByDeletingLastPathComponent];
			fpath = [path stringByAppendingPathComponent:fname];
		}
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Can't write %@ to non-existent '%@'.", name, path];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:3 userInfo:dict];
	}
	
	return fpath;
}

+ (NSError*)writeCriticalDataTo:(NSString*)path named:(NSString*)name with:(id<NSCoding>)object
{
	NSMutableData* data = [NSMutableData new];
	NSKeyedArchiver* archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
	[archiver setOutputFormat:NSPropertyListXMLFormat_v1_0];
	[archiver encodeObject:object];
	[archiver finishEncoding];
	
	NSError* error = nil;
	NSString* fpath = [Metadata criticalPath:path named:name outError:&error];
	if (fpath)
		[data writeToFile:fpath options:NSDataWritingAtomic error:&error];
	
	return error;
}

+ (id)readCriticalDataFrom:(NSString*)path named:(NSString*)name outError:(NSError**)error
{	
	NSString* fpath = [Metadata criticalPath:path named:name outError:error];
	if (fpath)
	{
		NSData* data = [NSData dataWithContentsOfFile:fpath options:0 error:error];
		if (data)
		{
			NSKeyedUnarchiver* archiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
			return [archiver decodeObject];
		}
	}
	
	return nil;
}

+ (void)writeNonCriticalDataTo:(NSString*)path named:(NSString*)name with:(id<NSCoding>)object
{
	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:object];
	
	int result = setxattr(path.UTF8String, name.UTF8String, data.bytes, data.length, 0, 0);
	if (result < 0)
		LOG("Warning", "Failed writing %s to %s: %s", STR(name), STR(path), strerror(errno));
}

+ (id)readNonCriticalDataFrom:(NSString*)path named:(NSString*)name
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
			LOG("Warning", "Failed reading %s from %s: %s", STR(name), STR(path), strerror(errno));
		}
	}
	return nil;
}

@end
