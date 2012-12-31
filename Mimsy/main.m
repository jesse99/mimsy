#import <Cocoa/Cocoa.h>

#import "ConfigParser.h"
#import "Logger.h"
#import "Paths.h"

static NSString* getAppVersion(void)
{
	NSString* result = nil;
	
    id version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    id buildNum = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
    if (version)
	{
    	if (buildNum)
    		result = [NSString stringWithFormat:@"%@ (%@)", version, buildNum];
    	else
    		result = [NSString stringWithFormat:@"%@", version];
    }
    else if (buildNum)
	{
    	result = [NSString stringWithFormat:@"%@", buildNum];
	}
	
	return result;
}

static void initLogging(void)
{
	// We hard-code the log file path to ensure that we can always log.
	NSString* path = [@"~/Library/Logs/mimsy.log" stringByExpandingTildeInPath];
	setupLogging(path.UTF8String);
	
	// Figure out which levels the user wants to log the various topics at.
	path = [Paths installedDir:@"settings"];
	path = [path stringByAppendingPathComponent:@"logging.mimsy"];
	
	NSError* error = nil;
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (!error)
	{
		[parser enumerate:
			^(ConfigParserEntry* entry)
			{
				setTopicLevel(entry.key.UTF8String, entry.value.UTF8String);
			}
		];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load %@:\n%@.", path, [error localizedFailureReason]];
		LOG_ERROR("Mimsy", "%s", STR(mesg));
	}
}

// When unit testing argv will contain a "-SenTest" switch.
int main(int argc, char *argv[])
{
	initLogging();
	
	NSDateFormatter* formatter = [NSDateFormatter new];
	[formatter setDateFormat:@"yyyy-MM-dd 'at' HH:mm"];				
	LOG("Mimsy", "Started up on %s", STR([formatter stringFromDate:[NSDate date]]));
		
	NSString* version = getAppVersion();
	if (version)
		LOG("Mimsy", "Version %s", STR(version));
	
	return NSApplicationMain(argc, (const char **)argv);	// note that we typically don't return from NSApplicationMain
}
