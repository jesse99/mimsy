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

- (bool)setSize:(unsigned long long)size
{
	UNUSED(size);
	return false;
}

- (void)closed
{
	// nothing to do for reads
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

@implementation ProcFileWriter
{
	NSString* (^_directory ) ();
	NSString* _fileName;
	void (^_contents)(NSString*);
	NSMutableData* _data;
}

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name contents:(void (^)(NSString*))contents;
{
	self = [super init];
	
	if (self)
	{
		_directory = directory;
		_fileName = name;
		_contents = contents;
		_data = [NSMutableData new];
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
	return _data.length;
}

- (bool)setSize:(unsigned long long)size
{
	[_data setLength:size];
	return true;
}

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{
	UNUSED(buffer, size, offset);
	
    if (error)
		*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil];
	
	return -1;
}

- (void)closed
{
	NSString* str = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
	if ([str endsWith:@"\n"])
		str = [str substringToIndex:str.length-1];
	_contents(str);
}

- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{	
	if (offset < 0 || offset > _data.length)
	{
		if (error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
		return -1;
	}
	else if (offset == _data.length)
	{
		[_data appendBytes:buffer length:size];
	}
	else if (offset < _data.length)
	{
		// This will grow data if needed.
		[_data replaceBytesInRange:NSMakeRange((NSUInteger)offset, 0) withBytes:buffer length:size];
	}
		
	return (int)size;
}

@end


