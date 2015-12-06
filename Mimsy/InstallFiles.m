#import "InstallFiles.h"

#import "ConfigParser.h"
#import "DataCategory.h"
#import "Logger.h"
#import "TranscriptController.h"
#import "Utils.h"

// ------------------------------------------------------------------------------------
@interface SourceFile : NSObject

- (id)init:(NSString*)srcPath;

@property (readonly) NSString* rpath;         // path relative to <bundle>/Resources
@property (readonly) NSString* srcPath;
@property NSString* srcHash;

@end

@implementation SourceFile

- (id)init:(NSString*)srcPath
{
    self = [super init];
    
    if (self)
    {
        _srcPath = srcPath;
        _rpath = [self _findRelativePath:srcPath];
    }
    
    return self;
}

- (NSString*)_findRelativePath:(NSString*)path
{
    NSArray* parts = [path pathComponents];
    
    NSUInteger i = parts.count >= 2 ? parts.count - 2 : 0;
    while (i > 0)
    {
        NSString* part = parts[i];
        if ([part isEqualToString:@"Resources"])
            break;
        --i;
    }
    
    ASSERT(i > 0);  // should always find Resources
    
    NSArray* subset = [parts subarrayWithRange:NSMakeRange(i+1, parts.count - i - 1)];
    NSString* rpath = [subset componentsJoinedByString:@"/"];
    return rpath;
}

@end

// ------------------------------------------------------------------------------------
@implementation InstallFiles
{
	NSString* _srcRoot;
    NSString* _dstRoot;
	NSMutableArray* _sources;

    NSString* _version;
	NSString* _build;
}

- (id)initWithDstPath:(NSString*)path
{
    self = [super init];
    
    if (self)
    {
        _srcRoot = NSBundle.mainBundle.resourcePath;
        if (![_srcRoot hasSuffix:@"/"])
            _srcRoot = [_srcRoot stringByAppendingString:@"/"];
        _dstRoot = path;
        
        _sources = [NSMutableArray new];
    }
    
    return self;
}

- (void)addSourceFile:(NSString*)item
{
    NSString* path = [_srcRoot stringByAppendingPathComponent:item];
	[_sources addObject:[[SourceFile alloc] init:path]];
}

- (void)addSourcePath:(NSString*)path
{
    [_sources addObject:[[SourceFile alloc] init:path]];
}

- (void)install
{
	if ([self _needsInstall])
	{
        double startTime = getTime();
        
        _sources = [self _gatherSourceFiles:_sources];
        NSDictionary* installedHashs = [self _getInstalledHashes];

        [self _saveManifest:installedHashs];
        [self _installFiles:installedHashs];

		double elapsed = getTime() - startTime;
		LOG("Mimsy", "Installed files in %.1f secs", elapsed);
	}
	else
	{
		LOG("Mimsy", "Skipped install (version and build match)");
	}
}

- (bool)_needsInstall
{
	NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
	NSString* version = info[@"CFBundleShortVersionString"];
	NSString* build = info[@"CFBundleVersion"];
	return ![version isEqualToString:_version] || ![build isEqualToString:_build];
}

- (void)_installFiles:(NSDictionary*)installedHashs
{
	NSFileManager* fm = [NSFileManager defaultManager];
	for (SourceFile* file in _sources)
	{
		NSString* installedHash = installedHashs[file.rpath];
		if ([@"ignore" isEqualToString:installedHash])
		{
			LOG("Mimsy", "Ignoring '%s'", STR(file.srcPath));
			continue;
		}
		
		// Checking the hashs makes the install process a bit more efficient because we don't have to
		// copy over files which haven't changed. But even more important this allows us to minimize
		// our overwriting of files the user has changed.
		NSString* dstPath = [_dstRoot stringByAppendingPathComponent:file.rpath];
		if (![file.srcHash isEqualToString:installedHash] || ![fm fileExistsAtPath:dstPath])
		{
			NSError* error = nil;
			if ([fm fileExistsAtPath:dstPath])
			{
				NSString* currentHash = [self _getHash:dstPath outError:&error];
				if (currentHash && ![currentHash isEqualToString:installedHash])
				{
					// Note that we need a new extension to avoid loading the old file.
                    // Although rtf files are annoying because they won't load properly
                    // if we change their extension. However those are loaded by name so
                    // it should be OK to keep the extension.
                    NSString* backupPath;
                    if ([dstPath hasSuffix:@".rtf"])
                        backupPath = [dstPath replaceCharacters:@".rtf" with:@".old.rtf"];
                    else
                        backupPath = [dstPath stringByAppendingString:@".old"];
                    
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
			
			if (![Utils copySrcFile:file.srcPath dstFile:dstPath outError:&error])
			{
				NSString* reason = [error localizedFailureReason];
				[TranscriptController writeError:reason];
				continue;
			}
			
			LOG("Mimsy", "Installed '%s'", STR(file.srcPath));
		}
	}
}

// Returns key -> hash for the file that was last installed
- (NSDictionary*)_getInstalledHashes
{
	NSMutableDictionary* files = [NSMutableDictionary new];
	NSString* path = [_dstRoot stringByAppendingPathComponent:@"manifest.mimsy"];
	
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

- (NSMutableArray*)_gatherSourceFiles:(NSArray*)inFiles
{
	NSMutableArray* outFiles = [NSMutableArray new];
	
	NSFileManager* fm = [NSFileManager defaultManager];
	for (SourceFile* file in inFiles)
	{
		BOOL isDir = NO;
		if ([fm fileExistsAtPath:file.srcPath isDirectory:&isDir])
		{
			if (isDir)
				[self _processSourceDirectory:outFiles forPath:file.srcPath];
			else
                [self _processSourceFile:outFiles forFile:file];
		}
		else
		{
			NSString* mesg = [NSString stringWithFormat:@"'%@' doesn't exist", file.srcPath];
			[TranscriptController writeError:mesg];
		}
	}
	
	return outFiles;
}

- (void)_processSourceDirectory:(NSMutableArray*)outFiles forPath:(NSString*)dir
{
    NSError* error = nil;
    [Utils enumerateDeepDir:dir glob:nil error:&error block:
     ^(NSString* path, bool* stop)
     {
         UNUSED(stop);
         [self _processSourceFile:outFiles forFile:[[SourceFile alloc] init:path]];
     }];
    if (error)
    {
        NSString* reason = [error localizedFailureReason];
        NSString* mesg = [NSString stringWithFormat:@"Couldn't install from '%@': %@", dir, reason];
        [TranscriptController writeError:mesg];
    }
}

- (void)_processSourceFile:(NSMutableArray*)outFiles forFile:(SourceFile*)file
{
	NSError* error = nil;
	file.srcHash = [self _getHash:file.srcPath outError:&error];
	if (file.srcHash)
    {
        [outFiles addObject:file];
    }
    else
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to read '%@': %@", file.srcPath, reason];
		[TranscriptController writeError:mesg];
	}
}

- (NSString*)_getHash:(NSString*)path outError:(NSError**)error
{
    NSData* data = [NSData dataWithContentsOfFile:path options:0 error:error];
    return data != nil ? [data md5sum] : nil;
}

- (void)_saveManifest:(NSDictionary*)installedHashs
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
	
	for (SourceFile* file in _sources)
	{
		NSString* hash = installedHashs[file.rpath];
		if ([@"ignore" isEqualToString:hash])
		{
			[contents appendFormat:@"%@: ignore\n", file.rpath];
		}
		else
		{
			[contents appendFormat:@"%@: %@\n", file.rpath, file.srcHash];
		}
	}

	[self _writeManifest:contents];
}

- (void)_writeManifest:(NSString*)contents
{
	NSString* path = [_dstRoot stringByAppendingPathComponent:@"manifest.mimsy"];
	LOG("Mimsy", "Writing %s", STR(path));
	
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
