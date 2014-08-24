#import "ProcFiles.h"

#import <OSXFUSE/OSXFUSE.h>

static GMUserFileSystem* _fs;

// Simple read-only fs: https://github.com/osxfuse/filesystems/tree/master/filesystems-objc/HelloFS
@implementation ProcFiles

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
		
		// Options are listed at: http://code.google.com/p/macfuse/wiki/OPTIONS
		// TODO: listen for kGMUserFileSystemDidMount and kGMUserFileSystemMountFailed
		NSString* icon = [[NSBundle mainBundle] pathForResource:@"tophat" ofType:@"icns"];
		NSArray* options = @[@"volname=MimsyFS", [NSString stringWithFormat:@"volicon=%@", icon]];
		[_fs mountAtPath:@"/Volumes/Mimsy" withOptions:options];
	}
	
	return self;
}

- (void)teardown
{
	[_fs unmount];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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

// TODO: register ReadHandler's (they should execute within the main thead)
- (NSArray*)contentsOfDirectoryAtPath:(NSString*)path error:(NSError**)error
{
	UNUSED(path, error);
	return @[@"version"];
}

- (NSData*)contentsAtPath:(NSString*)path
{
	if ([path isEqualToString:@"/version"])
		return [@"0.1b148" dataUsingEncoding:NSUTF8StringEncoding];
	return nil;
}

// TODO: report a better error for bogus path?
- (NSDictionary*)attributesOfItemAtPath:(NSString*)path userData:(id)userData error:(NSError**)error
{
	UNUSED(error, userData);
	
	if ([path isEqualToString:@"/"])
		return @{NSFileType: NSFileTypeDirectory};
	
	else if ([path isEqualToString:@"/version"])
		return @{NSFileType: NSFileTypeRegular, NSFileSize: @([@"0.1b148" length])};
	
	return nil;
}

@end
