#import "Languages.h"

#import "ConfigParser.h"
#import "ConditionalGlob.h"
#import "Paths.h"
#import "RegexStyler.h"
#import "TranscriptController.h"
#import "Utils.h"

static NSArray* _globs;		// [ConditionalGlob]
static NSArray* _stylers;	// [RegexStyler]

@implementation Languages

+ (void)setup
{
	[self _processFiles];
}

+ (RegexStyler*)findStylerWithFileName:(NSString*)name contents:(NSString*)text
{
	(void) name;
	(void) text;
	assert(_globs.count == _stylers.count);
	
	return nil;
}

+ (void)_processFiles
{
	assert(_globs == nil);
	
	NSMutableArray* globs = [NSMutableArray new];
	NSMutableArray* stylers = [NSMutableArray new];
	
	NSString* dir = [Paths installedDir:@"languages"];
	Glob* glob = [[Glob alloc] initWithGlob:@"*.mimsy"];
	
	NSError* error = nil;
	[Utils enumerateDir:dir glob:glob error:&error block:
	 ^(NSString* item)
	 {
		 [self _processFile:item globs:globs stylers:stylers];
	 }
	 ];
	if (error)
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load the language files at %@:\n%@.", dir, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
	}
	
	_globs = globs;
	_stylers = stylers;
}

+ (void)_processFile:(NSString*)path globs:(NSMutableArray*)globs stylers:(NSMutableArray*)stylers
{
	NSError* error = nil;
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (error)
		goto err;
	
	
	return;
	
err:
	NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load language %@:\n%@.", path, [error localizedFailureReason]];
	[TranscriptController writeError:mesg];
}

@end

// TODO:
// load languages from the bundle
// make sure we properly handle errors enumerating languages
// make sure we properly handle failures loading a language
// doesn't really make sense to have aync setup
// need a mapping from language name to RegexStyler
// might want a testSetup
