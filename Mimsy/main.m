#import <Cocoa/Cocoa.h>

#import "AppDelegate.h"
#import "AppSettings.h"
#import "ConfigParser.h"
#import "convertVIMFiles.h"
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
	initLogGlobs();
}

static void setupInfrastructure(void)
{
	initLogging();
	
	NSDateFormatter* formatter = [NSDateFormatter new];
	[formatter setDateFormat:@"yyyy-MM-dd 'at' HH:mm"];
	LOG("Mimsy", "\n\nStarted up on %s", STR([formatter stringFromDate:[NSDate date]]));
	
	NSString* version = getAppVersion();
	if (version)
		LOG("Mimsy", "Version %s", STR(version));
	
	// Unfortunately this only works for the main thread.
	NSAssertionHandler* handler = [AssertHandler new];
	[[[NSThread currentThread] threadDictionary] setValue:handler forKey:NSAssertionHandlerKey];
}

// These need to be registered rather early so, for the sake of convenience we do them all here.
static void registerAppSettings()
{
    [AppSettings registerSetting:@"AppendPath"];
	[AppSettings registerSetting:@"BuildError"];
	[AppSettings registerSetting:@"ContextHelp"];
	[AppSettings registerSetting:@"DefaultFindAllDirectory"];
	[AppSettings registerSetting:@"DontOpenWithMimsy"];
	[AppSettings registerSetting:@"EnableSubstitutions"];
	[AppSettings registerSetting:@"FindAllAlwaysExclude"];
	[AppSettings registerSetting:@"FindAllExcludes"];
	[AppSettings registerSetting:@"FindAllIncludes"];
	[AppSettings registerSetting:@"FindWraps"];
	[AppSettings registerSetting:@"IgnoredPath"];
	[AppSettings registerSetting:@"NumFindItems"];
	[AppSettings registerSetting:@"PasteCopiesBackColor"];
	[AppSettings registerSetting:@"PreferredPath"];
	[AppSettings registerSetting:@"ReversePaths"];
	[AppSettings registerSetting:@"SearchIn"];
	[AppSettings registerSetting:@"SearchWithin"];
	[AppSettings registerSetting:@"WarnWindowDelay"];
}

struct Options
{
	bool help;
	const char* vimDir;
	const char* outDir;
	const char* unknown;
};

static struct Options parseArgs(int argc, char* argv[])
{
	struct Options options = {0};
	
	for (int i = 1; i < argc; ++i)
	{
		if (strstr(argv[i], "--vim=") == argv[i])
			options.vimDir = argv[i] + strlen("--vim=");
		
		else if (strstr(argv[i], "--out=") == argv[i])
			options.outDir = argv[i] + strlen("--out=");
		
		else if (strstr(argv[i], "--help") == argv[i])	
			options.help = true;

		// These are present if we run this via the debugger.
		else if (strstr(argv[i], "-NSDocumentRevisionsDebugMode") == argv[i] || strstr(argv[i], "YES") == argv[i])
			;
		
		// These are present if we run this via unit tests.
		else if (strstr(argv[i], "-SenTest") == argv[i] || strstr(argv[i], "All") == argv[i])
			;
		
		else
			options.unknown = argv[i];
	}
	
	return options;
}

// Mimsy built by Xcode typically lands in a path like: /Users/jessejones/Library/Developer/Xcode/DerivedData/Mimsy-byxadmurikhtwdcdkkpaknvnsvsj/Build/Products/Debug/Mimsy.app
static void handleHelpOption(int code)
{
	printf("Usage: ./mimsy --vim=DIR --out=DIR\n");
	printf("\n");
	printf("--help     print his message and exit\n");
	printf("--out=DIR  directory in which to place generated files\n");
	printf("--vim=DIR  directory containing VIM files to be converted to style files\n");
	
	exit(code);
}

static void validateOptions(struct Options* options)
{
	if (options->help)
	{
		handleHelpOption(0);
	}
	if (options->vimDir)
	{
		if (!options->outDir)
		{
			printf("--out must be used if --vim is used\n");
			exit(1);
		}
	}
	if (options->unknown)
	{
		// The Finder passes in weird options like -psn_0_354533895 so we won't
		// bail if we get an unrecognized option.
		LOG("App", "Unknown option: %s\n", options->unknown);
	}
}

// When unit testing argv will contain a "-SenTest" switch.
int main(int argc, char* argv[])
{
	int result = 0;
	
	setupInfrastructure();
	registerAppSettings();
	
	struct Options options = parseArgs(argc, argv);
	validateOptions(&options);
	if (options.vimDir)
		convertVIMFiles([NSString stringWithUTF8String:options.vimDir], [NSString stringWithUTF8String:options.outDir]);
	else
		result = NSApplicationMain(argc, (const char **)argv);	// note that we typically don't return from NSApplicationMain
	
	return result;
}
