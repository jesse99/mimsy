#import "ProcFileSystem.h"

#import <OSXFUSE/OSXFUSE.h>

#import "ProcFile.h"
#import "TextController.h"

// Simple read-only fs: https://github.com/osxfuse/filesystems/tree/master/filesystems-objc/HelloFS
@implementation ProcFileSystem
{
	GMUserFileSystem* _fs;
	NSMutableArray* _files;
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
		_files = [NSMutableArray new];
		
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

- (void)add:(id<ProcFile>)file
{
	[_files addObject:file];
}

- (void)remove:(id<ProcFile>)file
{
	[_files removeObject:file];
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

#pragma mark read methods

- (NSArray*)contentsOfDirectoryAtPath:(NSString*)path error:(NSError**)error
{
	UNUSED(error);
	
	__block NSMutableArray* contents = [NSMutableArray new];

	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
	  ^{
		  NSArray* pathComponents = path.pathComponents;
		  
		  for (id<ProcFile> file in _files)
		  {
			  NSArray* fileComponents = file.path.pathComponents;
			  if ([fileComponents startsWith:pathComponents])
			  {
				  [contents addObject:fileComponents[pathComponents.count]];
			  }
		  }
	  });
	
	return contents;
}

- (BOOL)openFileAtPath:(NSString*)path
                  mode:(int)mode
              userData:(id*)userData
                 error:(NSError**)error
{
	UNUSED(mode);
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
	  ^{
		  // Sucky linear search but paths are dynamic and we shouldn't have all
		  // that many proc files.
		  for (id<ProcFile> file in _files)
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
	
	return *userData != nil;
}

- (void)releaseFileAtPath:(NSString*)path userData:(id)userData
{
	UNUSED(path, userData);
}

- (int)readFileAtPath:(NSString*)path
             userData:(id)userData
               buffer:(char*)buffer
                 size:(size_t)size
               offset:(off_t)offset
                error:(NSError**)error
{
	UNUSED(path);
	
	id<ProcFile> file = (id<ProcFile>) userData;
	int bytes = [file read:buffer size:size offset:offset error:error];
	return bytes;
}

- (NSDictionary*)attributesOfItemAtPath:(NSString*)path userData:(id)userData error:(NSError**)error
{
	UNUSED(error);
	
	if (userData)
	{
		id<ProcFile> file = (id<ProcFile>) userData;
		return @{NSFileType: NSFileTypeRegular, NSFileSize: @(file.size)};
	}
	else
	{
		id<ProcFile> file = nil;
		if ([self _isOurs:path file:&file])
		{
			if (file)
				return @{NSFileType: NSFileTypeRegular, NSFileSize: @(file.size)};
			else
				return @{NSFileType: NSFileTypeDirectory};
		}
	}
	
	return nil;
}

- (bool)_isOurs:(NSString*)path file:(id<ProcFile>*)file
{
	__block bool ours = false;
	__block id<ProcFile> tmpFile = nil;
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
	  ^{
		  NSArray* pathComponents = path.pathComponents;
		  
		  for (id<ProcFile> file in _files)
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
	  });
	
	*file = tmpFile;
	
	return ours;
}

@end
