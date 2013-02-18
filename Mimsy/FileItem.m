#import "FileItem.h"

#import "Logger.h"
#import "Utils.h"

@implementation FileItem
{
	NSString* _bytes;
}

- (id)initWithPath:(NSString*)path
{
	self = [super initWithPath:path];
	if (self)
	{
		[self reload:nil];
	}
	return self;
}

- (NSString*)bytes
{
	return _bytes;
}

- (bool)reload:(NSMutableArray*)added
{
	(void) added;
	
	NSUInteger bytes = [self _getBytes:self.path];
	NSString* newBytes = [Utils bytesToStr:bytes];
	if (![newBytes isEqualToString:_bytes])
	{
		_bytes = newBytes;
		return true;
	}
	
	return false;
}

- (NSUInteger)_getBytes:(NSString*)path
{
	__block NSUInteger bytes = 0;
	
	BOOL isDir;
	NSFileManager* fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:path isDirectory:&isDir])
	{
		NSError* error = nil;
		if (isDir)
		{
			if (![Utils enumerateDeepDir:path glob:nil error:&error block:	// this is the package case
				  ^(NSString* item) {bytes += [self _getBytes:item];}])
			{
				NSString* reason = [error localizedFailureReason];
				LOG_WARN("DirEditor", "error getting sizes for %s: %s", STR(path), STR(reason));
			}
		}
		else
		{
			NSDictionary* attrs = [fm attributesOfItemAtPath:path error:&error];	// ordinary file case
			if (attrs)
			{
				NSNumber* value = attrs[NSFileSize];
				bytes = value ? value.unsignedIntegerValue : 0;
			}
			else
			{
				// Warning because errors can happen as the file system changes (e.g. during
				// a build).
				NSString* reason = [error localizedFailureReason];
				LOG_WARN("DirEditor", "error getting size for %s: %s", STR(path), STR(reason));
			}
		}
	}

	return bytes;
}

@end
