#import "InstallFiles.h"

#import <CommonCrypto/CommonDigest.h>

#import "ConfigParser.h"
#import "DataCategory.h"
#import "Logger.h"
#import "TranscriptController.h"
#import "Utils.h"

@implementation InstallFiles
{
	NSString* _srcPath;
	NSMutableArray* _srcItems;		// files and directories relative to Resources to be processed
	NSDictionary* _srcFiles;		// relative source file name => md5sum

	NSString* _dstPath;
	NSDictionary* _dstFiles;		// relative dest file name => md5sum
	NSString* _version;
	NSString* _build;
}

- (id)init
{
	_srcPath = NSBundle.mainBundle.resourcePath;
	if (![_srcPath hasSuffix:@"/"])
		_srcPath = [_srcPath stringByAppendingString:@"/"];
	
	_srcItems = [NSMutableArray new];
	return self;
}

- (void)initWithDstPath:(NSString*)path
{
	_dstPath = path;
}

- (void)addSourceItem:(NSString*)item
{
	[_srcItems addObject:item];
}

- (void)install
{
	double startTime = getTime();

	_srcFiles = [self _findSourceFiles];
	_dstFiles = [self _findDestFiles];
	if ([self _needsInstall])
	{
		[self _saveManifest];
		[self _installFiles];

		double elapsed = getTime() - startTime;
		LOG_INFO("Mimsy", "Installed files in %.1f secs", elapsed);
	}
	else
	{
		LOG_INFO("Mimsy", "Skipped install (version and build match)");
	}
}

- (bool)_needsInstall
{
	NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
	NSString* version = info[@"CFBundleShortVersionString"];
	NSString* build = info[@"CFBundleVersion"];
	return ![version isEqualToString:_version] || ![build isEqualToString:_build];
}

- (void)_installFiles
{
	NSFileManager* fm = [NSFileManager defaultManager];
	for (NSString* rpath in _srcFiles)
	{
		NSString* newHash = _srcFiles[rpath];
		NSString* installedHash = _dstFiles[rpath];
		
		if ([@"ignore" isEqualToString:installedHash])
		{
			LOG_INFO("Mimsy", "Ignoring '%s'", STR(rpath));
			continue;
		}
		
		// Checking the hashs makes the install process a bit more efficient because we don't have to
		// copy over files which haven't changed. But even more important this allows us to minimize
		// our overwriting of files the user has changed.
		if (![newHash isEqualToString:installedHash])
		{
			NSString* srcPath = [_srcPath stringByAppendingPathComponent:rpath];
			NSString* dstPath = [_dstPath stringByAppendingPathComponent:rpath];
			
			NSError* error = nil;
			if ([fm fileExistsAtPath:dstPath])
			{
				NSString* actualHash = [self _getHash:dstPath outError:&error];
				if (actualHash && ![actualHash isEqualToString:installedHash])
				{
					NSString* ext = [dstPath pathExtension];
					
					NSString* backupPath = [dstPath stringByDeletingPathExtension];
					backupPath = [backupPath stringByAppendingString:@".old."];
					backupPath = [backupPath stringByAppendingString:ext];
					
					if ([Utils copySrcFile:dstPath dstFile:backupPath outError:&error])
					{
						NSString* mesg = [NSString stringWithFormat:@"Overwrote %@, old file saved to %@\n", dstPath, backupPath];
						[TranscriptController writeStdout:mesg];
					}
					else
					{
						NSString* reason = [error localizedFailureReason];
						NSString* mesg = [NSString stringWithFormat:@"Failed to backup '%@': %@", dstPath, reason];
						[TranscriptController writeError:mesg];
						continue;
					}
				}
			}
			
			if (![Utils copySrcFile:srcPath dstFile:dstPath outError:&error])
			{
				NSString* reason = [error localizedFailureReason];
				[TranscriptController writeError:reason];
				continue;
			}
			
			LOG_INFO("Mimsy", "Installed '%s'", STR(rpath));
		}
	}
}

- (NSDictionary*)_findDestFiles
{
	NSMutableDictionary* files = [NSMutableDictionary new];
	NSString* path = [_dstPath stringByAppendingPathComponent:@"manifest.mimsy"];
	
	NSFileManager* fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:path])
	{
		NSError* error = nil;
		ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
		if (parser)
		{
			[parser enumerate:
				^(ConfigParserEntry* entry)
				{
					if ([entry.key isEqualToString:@"version"])
					{
						_version = entry.value;
					}
					else if ([entry.key isEqualToString:@"build"])
					{
						_build = entry.value;
					}
					else
					{
						files[entry.key] = entry.value;
					}
				}
			 ];
		}
		else
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Error reading '%@': %@", path, reason];
			[TranscriptController writeError:mesg];
		}
	}
	
	return files;
}

- (NSDictionary*)_findSourceFiles
{
	NSMutableDictionary* files = [NSMutableDictionary new];
	
	NSFileManager* fm = [NSFileManager defaultManager];
	for (NSString* item in _srcItems)
	{
		NSString* path = [_srcPath stringByAppendingPathComponent:item];
		
		BOOL isDir = NO;
		if ([fm fileExistsAtPath:path isDirectory:&isDir])
		{
			if (isDir)
				[self _processSourceDirectory:files forItem:path];
			else
				[self _processSourceFile:files forItem:path];
		}
		else
		{
			NSString* mesg = [NSString stringWithFormat:@"'%@' doesn't exist", path];
			[TranscriptController writeError:mesg];
		}
	}
	
	return files;
}

- (NSString*)_getHash:(NSString*)path outError:(NSError**)error
{
	NSData* data = [NSData dataWithContentsOfFile:path options:0 error:error];
	if (data)
	{
		char buffer[CC_MD5_DIGEST_LENGTH] = {0};
		CC_MD5(data.bytes, (CC_LONG) data.length, (unsigned char*) buffer);
		
		NSData* hash = [NSData dataWithBytesNoCopy:buffer length:CC_MD5_DIGEST_LENGTH freeWhenDone:NO];
		return [hash base64EncodedString];
	}
	else
	{
		return nil;
	}
}

- (void)_processSourceFile:(NSMutableDictionary*)dict forItem:(NSString*)path
{
	NSError* error = nil;
	NSString* hash = [self _getHash:path outError:&error];
	if (hash)
	{
		NSString* rpath = [path substringFromIndex:_srcPath.length];
		dict[rpath] = hash;
	}
	else
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to read '%@': %@", path, reason];
		[TranscriptController writeError:mesg];
	}
}

- (void)_processSourceDirectory:(NSMutableDictionary*)dict forItem:(NSString*)dir
{
	NSError* error = nil;
	[Utils enumerateDeepDir:dir glob:nil error:&error block:
		^(NSString* item)
		{
			[self _processSourceFile:dict forItem:item];
		}
	];
	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Couldn't install from '%@': %@", dir, reason];
		[TranscriptController writeError:mesg];
	}
}

- (void)_saveManifest
{
	NSMutableString* contents = [NSMutableString stringWithCapacity:1024];
	[contents appendString:@"# This file contains the Mimsy version and build numbers along with md5\n"];
	[contents appendString:@"# sums for each file Mimsy installed into Application Support. In general\n"];
	[contents appendString:@"# this file should not be manually edited, but if you really want to you\n"];
	[contents appendString:@"# can replace a hash with 'ignore' to prevent Mimsy from installing a new\n"];
	[contents appendString:@"# version of the file.\n\n"];
	
	NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
	[contents appendFormat:@"version: %@\n", info[@"CFBundleShortVersionString"]];
	[contents appendFormat:@"build: %@\n\n", info[@"CFBundleVersion"]];
	
	for (NSString* rpath in _srcFiles)
	{
		NSString* installedHash = _dstFiles[rpath];
		if ([@"ignore" isEqualToString:installedHash])
		{
			[contents appendFormat:@"%@: ignore\n", rpath];
		}
		else
		{
			[contents appendFormat:@"%@: %@\n", rpath, _srcFiles[rpath]];
		}
	}

	[self _writeManifest:contents];
}

- (void)_writeManifest:(NSString*)contents
{
	NSString* path = [_dstPath stringByAppendingPathComponent:@"manifest.mimsy"];
	LOG_INFO("Mimsy", "Writing %s", STR(path));
	
	NSError* error = nil;
	NSFileManager* fm = [NSFileManager defaultManager];
	if (![fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error] || ![contents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error])
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to write '%@': %@", path, reason];
		[TranscriptController writeError:mesg];
	}
}

@end
