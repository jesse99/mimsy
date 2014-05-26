#import "Builders.h"

#import "Glob.h"
#import "Logger.h"
#import "Paths.h"
#import "StringCategory.h"
#import "TranscriptController.h"
#import "Utils.h"

static NSDictionary* _builders;	// name => builder path
static NSDictionary* _globs;	// name => glob

@implementation Builders

+ (NSDictionary*)builderInfo:(NSString*)dir
{
	if (!_builders)
		[self _loadBuilders];		// need to do this before the app finishes launching

	NSError* error = nil;
	NSFileManager* fm = [NSFileManager new];
	NSArray* entries = [fm contentsOfDirectoryAtPath:dir error:&error];
	if (entries)
	{
		for (NSString* filename in entries)
		{
			NSString* path = [dir stringByAppendingPathComponent:filename];
			for (NSString* name in _globs)
			{
				Glob* glob = _globs[name];
				if ([glob matchName:filename])
					return @{@"name": name, @"path": path};
			}
		}
	}
	else
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Couldn't iterate over files in %@: %@", dir, reason];
		[TranscriptController writeError:mesg];
	}

	return nil;
}

+ (NSArray*)getTargets:(NSDictionary*)info env:(NSDictionary*)vars
{
	NSArray* targets = nil;
	
	NSTask* task = [NSTask new];
	[task setLaunchPath:_builders[info[@"name"]]];
	[task setArguments:@[[NSString stringWithFormat:@"--path=%@", info[@"path"]]]];	// note that task arguments are not processed by a shell and so don't need to be quoted
	[task setEnvironment:vars];
	
	NSDictionary* json = [self _runBuilder:task];
	if (json)
	{
		NSString* error = json[@"error"];
		if (!error || error.length == 0)
		{
			targets = json[@"targets"];
		}
		else
		{
			[TranscriptController writeError:error];
		}
	}
	
	return targets;
}

+ (NSDictionary*)build:(NSDictionary*)info target:(NSString*)target flags:(NSString*)flags env:(NSDictionary*)vars
{
	NSDictionary* results = nil;
	
	NSMutableArray* args = [NSMutableArray new];
	[args addObject:[NSString stringWithFormat:@"--path=%@", info[@"path"]]];
	[args addObject:[NSString stringWithFormat:@"--target=%@", target]];
	if (flags && flags.length > 0)
	{
		[args addObject:@"--"];
		[args addObjectsFromArray:[flags splitByString:@" "]];
	}
	
	NSTask* task = [NSTask new];
	[task setLaunchPath:_builders[info[@"name"]]];
	[task setArguments:args];
	[task setEnvironment:vars];
	
	NSDictionary* json = [self _runBuilder:task];
	if (json)
	{
		NSString* error = json[@"error"];
		if (!error || error.length == 0)
		{
			results = @{
				@"tool": json[@"tool"],
				@"args": json[@"args"],
				@"cwd": [json[@"cwd"] stringByStandardizingPath],
			};
		}
		else
		{
			[TranscriptController writeError:error];
		}
	}
	
	return results;
}

+ (void)_loadBuilders
{
	__block NSMutableDictionary* builders = [NSMutableDictionary new];
	__block NSMutableDictionary* globs = [NSMutableDictionary new];
	NSString* dir = [Paths installedDir:@"builders"];
	
	NSError* error = nil;
	bool success = [Utils enumerateDir:dir glob:nil error:&error block:
		^(NSString* path)
		{
			if ([[NSFileManager defaultManager] isExecutableFileAtPath:path])
			{
				NSTask* task = [NSTask new];
				[task setLaunchPath:path];
				
				NSDictionary* json = [self _runBuilder:task];
				if (json)
				{
					NSString* name = json[@"name"];
					NSArray* value = json[@"globs"];
					builders[name] = path;
					globs[name] = [[Glob alloc] initWithGlobs:value];
				}
			}
		}
	];
	if (!success)
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Couldn't iterate over builders in %@: %@", dir, reason];
		[TranscriptController writeError:mesg];
	}
	_builders = builders;
	_globs = globs;
}

+ (NSDictionary*)_runBuilder:(NSTask*)task
{
	NSDictionary* result = nil;
	
	[task setStandardOutput:[NSPipe new]];
	[task setStandardError:[NSPipe new]];
	
	NSString* stderr = nil;
	NSError* err = [Utils run:task stdout:nil stderr:&stderr timeout:NoTimeOut];
	if (!err)
	{
		NSError* error = nil;
		NSData* data = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
		result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		if (!result)
		{
			NSString* mesg = [NSString stringWithFormat:@"Error running %@ %@", task.launchPath, [task.arguments componentsJoinedByString:@" "]];
			[TranscriptController writeError:mesg];

			NSString* reason = [error localizedFailureReason];
			NSString* text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			mesg = [NSString stringWithFormat:@"Couldn't convert '%@' to JSON: %@", text, reason];
			[TranscriptController writeError:mesg];
		}
	}
	else if (stderr.length > 0)
	{
		NSString* mesg = [NSString stringWithFormat:@"Error running %@ %@: %@", task.launchPath, [task.arguments componentsJoinedByString:@" "], stderr];
		[TranscriptController writeError:mesg];
	}
	else
	{
		int returncode = [err.userInfo[@"return code"] intValue];
		if (returncode)
		{
			NSString* mesg = [NSString stringWithFormat:@"Error running %@ %@: it returned with code %d", task.launchPath, [task.arguments componentsJoinedByString:@" "], returncode];
			[TranscriptController writeError:mesg];
		}
		else
		{
			NSString* mesg = [NSString stringWithFormat:@"Error running %@ %@: %@", task.launchPath, [task.arguments componentsJoinedByString:@" "], [err localizedFailureReason]];
			[TranscriptController writeError:mesg];
		}
	}
	
	return result;
}

@end
