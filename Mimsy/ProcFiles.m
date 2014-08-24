#import "ProcFiles.h"

#import <OSXFUSE/OSXFUSE.h>

#import "TextController.h"

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

// /text-window/<window-index>/text
// /text-window/<window-index>/title
// /text-window/<window-index>/path


// TODO: register ReadHandler's (they should execute within the main thead)
- (NSArray*)contentsOfDirectoryAtPath:(NSString*)path error:(NSError**)error
{
	UNUSED(error);
	
	__block NSMutableArray* contents = [NSMutableArray new];

	if ([path isEqualToString:@"/"])
	{
		[contents addObject:@"text-window"];
		[contents addObject:@"version"];
	}
	else if ([path isEqualToString:@"/text-window"])
	{
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_sync(main,
		  ^{
			  __block int index = 1;
			  [TextController enumerate:^(TextController *controller) {
				  UNUSED(controller);
				  [contents addObject:[NSString stringWithFormat:@"%d", index]];
				  ++index;
			  }];
		  });
	}
	else if ([path isEqualToString:@"/text-window/1"] || [path isEqualToString:@"/text-window/2"] || [path isEqualToString:@"/text-window/3"] || [path isEqualToString:@"/text-window/4"])
	{
		[contents addObject:@"text"];
		[contents addObject:@"title"];
		[contents addObject:@"path"];
	}
	else
	{
		contents = nil;
	}
	
	return contents;
}

- (TextController*)_findTextController:(NSString*)path
{
	__block TextController* result = nil;
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_sync(main,
	  ^{
		  __block int index = 1;
		  [TextController enumerate:^(TextController *controller) {
			  if ([path startsWith:[NSString stringWithFormat:@"/text-window/%d", index]])
				  result = controller;
			  ++index;
		  }];
	  });
	
	return result;
}

- (NSData*)contentsAtPath:(NSString*)path
{
	if ([path isEqualToString:@"/version"])
	{
		return [@"0.1b148" dataUsingEncoding:NSUTF8StringEncoding];
	}
	else if ([path endsWith:@"/text"])
	{
		TextController* controller = [self _findTextController:path];
		if (controller)
		{
			return [controller.text dataUsingEncoding:NSUTF8StringEncoding];
		}
	}
	else if ([path endsWith:@"/title"])
	{
		TextController* controller = [self _findTextController:path];
		if (controller)
		{
			return [controller.window.title dataUsingEncoding:NSUTF8StringEncoding];
		}
	}
	else if ([path endsWith:@"/path"])
	{
		TextController* controller = [self _findTextController:path];
		if (controller)
		{
			return [controller.path dataUsingEncoding:NSUTF8StringEncoding];
		}
	}
	
	return nil;
}

// TODO: report a better error for bogus path?
- (NSDictionary*)attributesOfItemAtPath:(NSString*)path userData:(id)userData error:(NSError**)error
{
	UNUSED(error, userData);
	
	if ([path isEqualToString:@"/"] || [path isEqualToString:@"/text-window"] || [path isEqualToString:@"/text-window/1"] || [path isEqualToString:@"/text-window/2"] || [path isEqualToString:@"/text-window/3"] || [path isEqualToString:@"/text-window/4"])
		return @{NSFileType: NSFileTypeDirectory};
	
	else if ([path isEqualToString:@"/version"])
		return @{NSFileType: NSFileTypeRegular, NSFileSize: @([@"0.1b148" length])};
	
	else if ([path endsWith:@"/text"])
	{
		TextController* controller = [self _findTextController:path];
		if (controller)
		{
			return @{NSFileType: NSFileTypeRegular, NSFileSize: @([controller.text length])};
		}
	}
	else if ([path endsWith:@"/title"])
	{
		TextController* controller = [self _findTextController:path];
		if (controller)
		{
			return @{NSFileType: NSFileTypeRegular, NSFileSize: @([controller.window.title length])};
		}
	}
	else if ([path endsWith:@"/path"])
	{
		TextController* controller = [self _findTextController:path];
		if (controller)
		{
			return @{NSFileType: NSFileTypeRegular, NSFileSize: @([controller.path length])};
		}
	}

	return nil;
}

@end
