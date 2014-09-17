#import "ProcFileSystem.h"

#import <OSXFUSE/OSXFUSE.h>

#import "ProcFile.h"
#import "TextController.h"

// In general the delegate methods here can be called from within any thread. We can set
// isThreadSafe to false but all that does is force OSXFUSE to call us from a single
// thread.
//
// This is a problem because we need to access state like NSTextViews which are difficult
// to serialize access to and we need to support blocking invocations into extensions for
// things like key processing. I don't think there is a good solution for this: either we
// somehow make Mimsy state thread safe or we somehow make event processing asynchronous.
// Neither of those seem at all attractive so, for now, we require that our file system
// only be accessed in response to a Mimsy invocation.
//
// TODO: This does mean that fancy extensions can't spin up a thread and defer writes.
// Not sure of the best way to handle this. Perhaps the extension can write to a special
// extension specific file and Mimsy can call it back on the main thread.
@implementation ProcFileSystem
{
	GMUserFileSystem* _fs;
	NSMutableArray* _allFiles;
	NSMutableArray* _readers;
	NSMutableArray* _writers;
}

- (id)init
{
	self = [super init];
	
	if (self)
	{
		_fs = [[GMUserFileSystem alloc] initWithDelegate:self isThreadSafe:true];
		_allFiles = [NSMutableArray new];
		_readers = [NSMutableArray new];
		_writers = [NSMutableArray new];
		
		// Options are listed at: http://code.google.com/p/macfuse/wiki/OPTIONS
		// TODO: listen for kGMUserFileSystemDidMount and kGMUserFileSystemMountFailed
		NSString* icon = [[NSBundle mainBundle] pathForResource:@"tophat" ofType:@"icns"];
		NSArray* options = @[
			@"nolocalcaches",	// this seems to be the only way to handle files whose contents dynamically change
			@"volname=MimsyFS",
			[NSString stringWithFormat:@"volicon=%@", icon]];
		[_fs mountAtPath:@"/Volumes/Mimsy" withOptions:options];
	}
	
	return self;
}

- (void)teardown
{
	[_fs unmount];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addReader:(id<ProcFile>)file
{
	[_allFiles addObject:file];
	[_readers addObject:file];
}

- (void)removeReader:(id<ProcFile>)file
{
	[_allFiles removeObject:file];
	[_readers removeObject:file];
}

- (void)addWriter:(id<ProcFile>)file
{
	[_allFiles addObject:file];
	[_writers addObject:file];
}

- (void)removeWriter:(id<ProcFile>)file
{
	[_allFiles removeObject:file];
	[_writers removeObject:file];
}

- (BOOL)openFileAtPath:(NSString*)path
                  mode:(int)mode
              userData:(id*)userData
                 error:(NSError**)error
{
	*userData = nil;
	
	if (mode == O_RDONLY)
		LOG("ProcFS:Verbose", "opening %s read-only", STR(path));
	else if (mode == O_WRONLY)
		LOG("ProcFS:Verbose", "opening %s write-only", STR(path));
	else if (mode == O_RDWR)
		LOG("ProcFS:Verbose", "opening %s read-write", STR(path));

	if (mode == O_RDONLY)
	{
		  // Sucky linear search but paths are dynamic and we shouldn't have all
		  // that many proc files.
		  for (id<ProcFile> file in _readers)
		  {
			  if ([path isEqualToString:file.path])
			  {
				  if ([file openForRead:true write:false])
					  *userData = file;
				  break;
			  }
		  }
		if (!*userData && error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:nil];
	}
	if (!*userData && (mode == O_RDONLY || mode == O_WRONLY || mode == O_RDWR))
	{
		  for (id<ProcFile> file in _writers)
		  {
			  if ([path isEqualToString:file.path])
			  {
				  if ([file openForRead:mode != O_WRONLY write:mode != O_RDONLY])
					  *userData = file;
				  break;
			  }
		  }
		if (!*userData && error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:nil];
	}
	else if (error)
	{
		*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil];
	}
	if (*userData != nil)
		LOG("ProcFS:Verbose", "finished opening");
	else
		LOG("ProcFS:Verbose", "error opening: %s", STR([*error localizedFailureReason]));
		
	return *userData != nil;
}

- (void)releaseFileAtPath:(NSString*)path userData:(id)userData
{
	LOG("ProcFS:Verbose", "releasing %s", STR(path));
	
	id<ProcFile> file = (id<ProcFile>) userData;
	[file close];
	LOG("ProcFS:Verbose", "released");
}

#pragma mark read methods

- (NSArray*)contentsOfDirectoryAtPath:(NSString*)path error:(NSError**)error
{
	UNUSED(error);
	
	NSMutableArray* contents = [NSMutableArray new];

	  NSArray* pathComponents = path.pathComponents;
	  
	  for (id<ProcFile> file in _allFiles)
	  {
		  NSArray* fileComponents = file.path.pathComponents;
		  if ([fileComponents startsWith:pathComponents])
		  {
			  NSString* name = fileComponents[pathComponents.count];
			  if (![contents containsObject:name])
				  [contents addObject:name];
		  }
	  }
	
	return contents;
}

- (int)readFileAtPath:(NSString*)path
             userData:(id)userData
               buffer:(char*)buffer
                 size:(size_t)size
               offset:(off_t)offset
                error:(NSError**)error
{
	LOG("ProcFS:Verbose", "reading %zu bytes at %lld from %s", size, offset, STR(path));
	
	int bytes = 0;
	
	  id<ProcFile> file = (id<ProcFile>) userData;
	  bytes = [file read:buffer size:size offset:offset error:error];
	
	return bytes;
}

- (NSDictionary*)attributesOfItemAtPath:(NSString*)path userData:(id)userData error:(NSError**)error
{
	UNUSED(error);
	LOG("ProcFS:Verbose", "getting attributes for %s", STR(path));
	
	NSDictionary* attrs = nil;
	
	  if (userData)
	  {
		  id<ProcFile> file = (id<ProcFile>) userData;
		  attrs = @{NSFileType: NSFileTypeRegular, NSFileSize: @(file.size)};
	  }
	  else
	  {
		  id<ProcFile> file = nil;
		  if ([self _isOurs:path file:&file])
		  {
			  if (file)
				  attrs = @{NSFileType: NSFileTypeRegular, NSFileSize: @(file.size)};
			  else
				  attrs = @{NSFileType: NSFileTypeDirectory};
		  }
	  }
	
	return attrs;
}

- (bool)_isOurs:(NSString*)path file:(id<ProcFile>*)file
{
	bool ours = false;
	id<ProcFile> tmpFile = nil;
	
	NSArray* pathComponents = path.pathComponents;
	  
	for (id<ProcFile> file in _allFiles)
	{
		NSArray* fileComponents = file.path.pathComponents;
		if ([fileComponents startsWith:pathComponents])
		{
			ours = true;
		}
		  
		if ([file.path isEqualToString:path])
		{
			 tmpFile = file;
			break;
		}
	}
	
	*file = tmpFile;
	
	return ours;
}

#pragma mark write methods

- (BOOL)setAttributes:(NSDictionary*)attributes
         ofItemAtPath:(NSString*)path
             userData:(id)userData
                error:(NSError**)error
{
	UNUSED(error);
	LOG("ProcFS:Verbose", "setting %s attributes for %s", STR(attributes), STR(path));
	
	BOOL result = NO;
	  NSNumber* size = attributes[NSFileSize];
	  if (size && userData)
	  {
		  id<ProcFile> file = (id<ProcFile>) userData;
		  result = [file setSize:size.unsignedLongLongValue];
	  }
	  
	  if (!result && error)
		  *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil];
	LOG("ProcFS:Verbose", "finished setting attributes");
	
	return result;
}

- (int)writeFileAtPath:(NSString*)path
              userData:(id)userData
                buffer:(const char*)buffer
                  size:(size_t)size
                offset:(off_t)offset
                 error:(NSError**)error
{
	LOG("ProcFS:Verbose", "writing %zu bytes at %lld for %s", size, offset, STR(path));
	
	int bytes = 0;
	
	  id<ProcFile> file = (id<ProcFile>) userData;
	  bytes = [file write:buffer size:size offset:offset error:error];
	LOG("ProcFS:Verbose", "wrote %d bytes", bytes);
	
	return bytes;
}

@end
