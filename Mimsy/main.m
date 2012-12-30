#import <Cocoa/Cocoa.h>
#import "Logger.h"

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

int main(int argc, char *argv[])
{
	setupLogging();
	
	LOG("Mimsy", "Started up on %@", [NSDate date]);
	NSString* version = getAppVersion();
	if (version)
		LOG("Mimsy", "Version %@", version);
	
	return NSApplicationMain(argc, (const char **)argv);	// note that we typically don't return from NSApplicationMain
}
