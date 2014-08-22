#import "FileItem.h"

#import "DirectoryController.h"
#import "Logger.h"
#import "Utils.h"

@implementation FileItem
{
	NSAttributedString* _name;
	NSAttributedString* _bytes;
}

- (id)initWithPath:(NSString*)path controller:(DirectoryController*)controller
{
	self = [super initWithPath:path controller:controller];
	if (self)
	{
		NSString* name = [path lastPathComponent];
		NSDictionary* attrs = [controller getFileAttrs:name];
		_name = [[NSAttributedString alloc] initWithString:name attributes:attrs];
		
		[self reload:nil];
	}
	return self;
}

- (NSAttributedString*) name
{
	return _name;
}

- (NSAttributedString*)bytes
{
	return _bytes;
}

- (bool)reload:(NSMutableArray*)added
{
	(void) added;
	
	DirectoryController* controller = self.controller;
	if (controller)
	{
		NSString* name = [self.path lastPathComponent];
		NSDictionary* attrs = [controller getFileAttrs:name];
		_name = [[NSAttributedString alloc] initWithString:name attributes:attrs];
	}
	
	NSUInteger bytes = [self _getBytes:self.path];
	NSDictionary* attrs = [controller getSizeAttrs];
	NSAttributedString* newBytes = [[NSAttributedString alloc] initWithString:[Utils bytesToStr:bytes] attributes:attrs];
	if (![newBytes isEqual:_bytes])
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
				LOG("Warning", "error getting sizes for %s: %s", STR(path), STR(reason));
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
				LOG("Warning", "error getting size for %s: %s", STR(path), STR(reason));
			}
		}
	}

	return bytes;
}

@end
