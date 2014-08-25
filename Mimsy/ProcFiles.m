#import "ProcFiles.h"

@implementation ProcFileReader
{
	NSString* (^_directory ) ();
	NSString* _fileName;
	NSString* (^_contents)();
}

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name contents:(NSString* (^)())contents;
{
	self = [super init];
	
	if (self)
	{
		_directory = directory;
		_fileName = name;
		_contents = contents;
	}
	
	return self;
}

- (NSString*)description
{
	return self.path;
}

- (NSString*)path
{
	NSString* directory = _directory();
	NSString* path = [directory stringByAppendingPathComponent:_fileName];
	return path;
}

- (unsigned long long)size
{
	NSString* contents = _contents();
	NSData* data = [contents dataUsingEncoding:NSUTF8StringEncoding];
	return data.length;
}

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{
	NSString* contents = _contents();
	NSData* data = [contents dataUsingEncoding:NSUTF8StringEncoding];
	
	if (offset < 0 || offset > data.length)
	{
		if (error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
		return -1;
	}
	else if (offset == data.length)
	{
		return 0;
	}
	
	int bytes = MIN((int) ((off_t) data.length - offset), (int) size);
	memcpy(buffer, data.bytes, bytes);
	
	return bytes;
}

- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{
	UNUSED(buffer, size, offset);
	
    if (error)
		*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil];
	
	return -1;
}

@end

