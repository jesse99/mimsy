#import "ProcFileSystem.h"

#import <OSXFUSE/OSXFUSE.h>

#import "ProcFile.h"
#import "TextController.h"

// Simple read-only fs: https://github.com/osxfuse/filesystems/tree/master/filesystems-objc/HelloFS
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
		NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
		[center addObserver:self selector:@selector(_didMount:)
					   name:kGMUserFileSystemDidMount object:nil];
		[center addObserver:self selector:@selector(_mountFailed:)
					   name:kGMUserFileSystemMountFailed object:nil];

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

// TODO:
// Notification should be handled by the app delegate
// On success load extensions
// On failure write to the transcript (do the moutning fairly late)
- (void)_didMount:(NSNotification*)notification
{
	NSDictionary* userInfo = [notification userInfo];
	NSString* path = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
	LOG("Mimsy", "mounted %s", STR(path));
}

- (void)_mountFailed:(NSNotification*)notification
{
	NSDictionary* userInfo = [notification userInfo];
	NSString* path = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
	NSError* error = [userInfo objectForKey:kGMUserFileSystemErrorKey];
	LOG("Error", "failed to mount %s: %s", STR(path), STR(error.localizedFailureReason));
}

- (BOOL)openFileAtPath:(NSString*)path
                  mode:(int)mode
              userData:(id*)userData
                 error:(NSError**)error
{
	*userData = nil;
	
	dispatch_queue_t main = dispatch_get_main_queue();
	if (mode == O_RDONLY)
	{
		dispatch_sync(main,
		  ^{
			  // Sucky linear search but paths are dynamic and we shouldn't have all
			  // that many proc files.
			  for (id<ProcFile> file in _readers)
			  {
				  if ([path isEqualToString:file.path])
				  {
					  *userData = file;
					  break;
				  }
			  }
		  });
		if (!*userData && error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:nil];
	}
	else if (mode == O_WRONLY)
	{
		dispatch_sync(main,
		  ^{
			  for (id<ProcFile> file in _writers)
			  {
				  if ([path isEqualToString:file.path])
				  {
					  *userData = file;
					  break;
				  }
			  }
		  });
		if (!*userData && error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:nil];
	}
	else if (error)
	{
		*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil];
	}
		
	return *userData != nil;
}

- (void)releaseFileAtPath:(NSString*)path userData:(id)userData
{
	UNUSED(path);
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
		^{
			id<ProcFile> file = (id<ProcFile>) userData;
			[file closed];
		});
}

#pragma mark read methods

- (NSArray*)contentsOfDirectoryAtPath:(NSString*)path error:(NSError**)error
{
	UNUSED(error);
	
	__block NSMutableArray* contents = [NSMutableArray new];

	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
	  ^{
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
	  });
	
	return contents;
}

- (int)readFileAtPath:(NSString*)path
             userData:(id)userData
               buffer:(char*)buffer
                 size:(size_t)size
               offset:(off_t)offset
                error:(NSError**)error
{
	UNUSED(path);
	
	__block int bytes = 0;
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
	  ^{
		  id<ProcFile> file = (id<ProcFile>) userData;
		  bytes = [file read:buffer size:size offset:offset error:error];
	  });
	
	return bytes;
}

- (NSDictionary*)attributesOfItemAtPath:(NSString*)path userData:(id)userData error:(NSError**)error
{
	UNUSED(error);
	
	__block NSDictionary* attrs = nil;
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
	  ^{
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
	  });
	
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
	UNUSED(path, error);
	
	__block BOOL result = NO;
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
	  ^{
		  NSNumber* size = attributes[NSFileSize];
		  if (size && userData)
		  {
			  id<ProcFile> file = (id<ProcFile>) userData;
			  result = [file setSize:size.unsignedLongLongValue];
		  }
		  
		  if (!result && error)
			  *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil];
	  });
	
	return result;
}

- (int)writeFileAtPath:(NSString*)path
              userData:(id)userData
                buffer:(const char*)buffer
                  size:(size_t)size
                offset:(off_t)offset
                 error:(NSError**)error
{
	UNUSED(path);
	
	__block int bytes = 0;
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
	  ^{
		  id<ProcFile> file = (id<ProcFile>) userData;
		  bytes = [file write:buffer size:size offset:offset error:error];
	  });
	
	return bytes;
}

@end
