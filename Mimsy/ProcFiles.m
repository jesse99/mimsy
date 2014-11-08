#import "ProcFiles.h"

#import "Extensions.h"

@implementation ProcFileReader
{
	NSString* _value;
	NSString* (^_directory ) ();
	NSString* _fileName;
	NSString* (^_readStr)();
	NSData* _data;
}

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name readStr:(NSString* (^)())readStr;
{
	self = [super init];
	
	if (self)
	{
		_directory = directory;
		_fileName = name;
		_readStr = readStr;
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

static bool matchesAnyDirectory(NSString* path, NSString* directory)
{
	while (directory.length > 0 && ![directory isEqualToString:@"/"])
	{
		if ([directory isEqualToString:path])
			return true;
		
		directory = [directory stringByDeletingLastPathComponent];
	}
	
	return false;
}

- (bool)matchesAnyDirectory:(NSString*)path
{
	return matchesAnyDirectory(path, _directory());
}

- (bool)matchesFile:(NSString*)path
{
	return [self.path isEqualToString:path];
}

static NSArray* directChildren(NSString* path, NSString* directory, NSString* fileName)
{
	if ([directory isEqualToString:path])
	{
		return @[fileName];
	}
	else
	{
		while (directory.length > 0 && ![directory isEqualToString:@"/"])
		{
			NSString* child = directory.lastPathComponent;
			directory = [directory stringByDeletingLastPathComponent];
			
			if ([directory isEqualToString:path])
				return @[child];
		}
	}
	
	return @[];
}

- (NSArray*)directChildren:(NSString*)path
{
	return directChildren(path, _directory(), _fileName);
}

- (bool)openPath:(NSString*)path read:(bool)reading write:(bool)writing
{
	UNUSED(path);
	ASSERT(!writing);
	ASSERT(reading);
	// not much point in doing anything here given that size can be called before opened
	return true;
}

- (void)close;
{
	_data = nil;
}

- (unsigned long long)sizeFor:(NSString*)path
{
	UNUSED(path);
	
	NSString* contents = _readStr();
	_data = [contents dataUsingEncoding:NSUTF8StringEncoding];
	return _data.length;
}

- (bool)setSize:(unsigned long long)size
{
	UNUSED(size);
	return false;
}

+ (int)readInto:(char*)buffer size:(size_t)size offset:(off_t)offset from:(NSData*)data error:(NSError**)error
{
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
	memcpy(buffer, data.bytes + offset, (unsigned long)bytes);
	
	return bytes;
}

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{
	if (!_data)
	{
		// Most of the time I think size will be called before read, but that's not a
		// requirement.
		NSString* contents = _readStr();
		_data = [contents dataUsingEncoding:NSUTF8StringEncoding];
	}
	
	return [ProcFileReader readInto:buffer size:size offset:offset from:_data error:error];
}

- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{
	UNUSED(buffer, size, offset);
	
    if (error)
		*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil];
	
	return -1;
}

- (void)notifyIfChanged;
{
	if ([Extensions watching:self.path])
	{
		NSString* newValue = _readStr();
		if ([newValue compare:_value] != NSOrderedSame)
		{
			if (_value)
				[Extensions invoke:self.path];
			_value = newValue;
		}
	}
}

@end

// Note that the order of operations can be very weird, e.g. for
//    echo 'x' > /Volumes/Mimsy/text-window/1/selection-text
// I got:
// getting size
// opened for write
// 	setting size to 0
// 	getting size
// 	getting size
// 	opened for read
// 	   reading 6 bytes at 0
// 	   writing 6 bytes at 0
// closed for write				note that the write is closed before the read
// getting size
// closed for read
// getting size
@implementation ProcFileReadWrite
{
	NSString* _value;
	NSString* (^_directory ) ();
	NSString* _fileName;
	NSString* (^_readStr)();
	void (^_writeStr)(NSString*);
	NSMutableData* _data;			// this is used if we're open for writing
}

- (id)initWithDir:(NSString* (^) ())directory fileName:(NSString*)name readStr:(NSString* (^)())readStr writeStr:(void (^)(NSString*))writeStr;
{
	self = [super init];
	
	if (self)
	{
		_directory = directory;
		_fileName = name;
		_readStr = readStr;
		_writeStr = writeStr;
		
		_value = _readStr();
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

- (bool)matchesAnyDirectory:(NSString*)path
{
	return matchesAnyDirectory(path, _directory());
}

- (bool)matchesFile:(NSString*)path
{
	return [self.path isEqualToString:path];
}

- (NSArray*)directChildren:(NSString*)path
{
	return directChildren(path, _directory(), _fileName);
}

- (bool)openPath:(NSString*) path read:(bool)reading write:(bool)writing
{
	UNUSED(path, reading);
	
	// Don't allow a process to open the file if another process has the file
	// opened for writes. This should be OK because extensions should execute
	// when triggered by Mimsy which will serialize their execution.
	bool ok = _data == nil;
	
	if (writing && ok)
	{
		NSString* contents = _readStr();
		_data = [[contents dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
	}
	
	return ok;
}

- (void)close;
{
	if (_data)
	{
		NSString* str = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
		if ([str endsWith:@"\n"])
			str = [str substringToIndex:str.length-1];
		_writeStr(str);
		
		_data = nil;
	}
}

- (unsigned long long)sizeFor:(NSString*)path
{
	UNUSED(path);
	
	if (_data)
	{
		return _data.length;
	}
	else
	{
		NSString* contents = _readStr();
		NSData* data = [contents dataUsingEncoding:NSUTF8StringEncoding];
		return data.length;
	}
}

- (bool)setSize:(unsigned long long)size
{
	ASSERT(_data);
	
	[_data setLength:size];
	return true;
}

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{
	NSData* data = _data;
	if (!_data)
	{
		NSString* contents = _readStr();
		data = [contents dataUsingEncoding:NSUTF8StringEncoding];
	}
	
	return [ProcFileReader readInto:buffer size:size offset:offset from:data error:error];
}

- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{
	ASSERT(_data);
	
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
		NSRange range = NSMakeRange((NSUInteger)offset, MIN(size, _data.length-(NSUInteger)offset));
		[_data replaceBytesInRange:range withBytes:buffer length:size];
	}
	
	return (int)size;
}

- (void)notifyIfChanged;
{
	if ([Extensions watching:self.path])
	{
		NSString* newValue = _readStr();
		if ([newValue compare:_value] != NSOrderedSame)
		{
			[Extensions invoke:self.path];
			_value = newValue;
		}
	}
}

@end

@implementation ProcFileKeyStore
{
	NSMutableDictionary* _store;
	NSString* (^_directory ) ();
	NSMutableData* _data;			// this is used if we're open for writing
	NSString* _openedKey;
	bool _dirty;
}

- (id)initWithDir:(NSString* (^) ())directory;
{
	self = [super init];
	
	if (self)
	{
		_store = [NSMutableDictionary new];
		_directory = directory;
	}
	
	return self;
}

- (NSString*)description
{
	return _directory();
}

- (bool)matchesAnyDirectory:(NSString*)path
{
	return matchesAnyDirectory(path, _directory());
}

- (bool)matchesFile:(NSString*)path
{
	NSString* directory = _directory();
	NSString* root = [path stringByDeletingLastPathComponent];
	
	return [directory isEqualToString:root];
}

- (NSArray*)directChildren:(NSString*)path
{
	NSString* directory = _directory();
	if ([directory isEqualToString:path])
	{
		return _store.allKeys;
	}
	else
	{
		return directChildren(path, directory, @"not a valid file name");
	}
}

- (bool)openPath:(NSString*) path read:(bool)reading write:(bool)writing
{
	UNUSED(path, reading, writing);
	
	// Don't allow a process to open the file if another process has the file
	// opened. This should be OK because extensions should execute
	// when triggered by Mimsy which will serialize their execution.
	bool ok = _data == nil;
	
	if (ok)
	{
		_openedKey = path.lastPathComponent;
		_data = _store[_openedKey];
		
		if (!_data)
		{
			_data = [NSMutableData new];
			_store[_openedKey] = _data;
		}
		
		_dirty = false;
	}
	
	return ok;
}

- (void)close;
{
	NSString* key = _openedKey;
	
	_data = nil;
	_openedKey = nil;
	
	if (key && _dirty)
		[self _notifyChanged:key];
}

- (unsigned long long)sizeFor:(NSString*)path
{
	NSString* key = path.lastPathComponent;
	NSData* data = _store[key];
	return data ? data.length : 0;
}

- (bool)setSize:(unsigned long long)size
{
	ASSERT(_data);
	
	if (size != _data.length)
	{
		[_data setLength:size];
		_dirty = true;
	}
	
	return true;
}

- (int)read:(char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{
	ASSERT(_data);

	return [ProcFileReader readInto:buffer size:size offset:offset from:_data error:error];
}

- (int)write:(const char*)buffer size:(size_t)size offset:(off_t)offset error:(NSError**)error
{	
	ASSERT(_data);

	if (offset < 0 || offset > _data.length)
	{
		if (error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
		return -1;
	}
	else if (offset == _data.length)
	{
		[_data appendBytes:buffer length:size];
		_dirty = true;
	}
	else if (offset < _data.length)
	{
		// This will grow data if needed.
		NSRange range = NSMakeRange((NSUInteger)offset, MIN(size, _data.length-(NSUInteger)offset));
		[_data replaceBytesInRange:range withBytes:buffer length:size];
		_dirty = true;
	}
		
	return (int)size;
}

- (void)_notifyChanged:(NSString*)key;
{
	NSString* directory = _directory();
	NSString* path = [directory stringByAppendingPathComponent:key];

	if ([Extensions watching:path])
		[Extensions invoke:path];
}

@end
