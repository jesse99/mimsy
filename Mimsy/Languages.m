#import "Languages.h"

#import "Assert.h"
#import "ConfigParser.h"
#import "ConditionalGlob.h"
#import "Language.h"
#import "Paths.h"
#import "RegexStyler.h"
#import "TranscriptController.h"
#import "Utils.h"

static NSArray* _languages;

@implementation Languages

+ (void)setup
{
	[self _processFiles];
}

+ (Language*)findWithFileName:(NSString*)name contents:(NSString*)text
{
	Language* lang = nil;
	int best = 0;
	
	for (Language* candidate in _languages)
	{
		// Unfortunately some files (notably *.h) can match multiple
		// languages so we need to try more than just the first match.
		int weight = [candidate.glob matchName:name contents:text];
		if (weight > best)
		{
			lang = candidate;
			best = weight;
		}
	}
	
	return lang;
}

+ (Language*)findWithlangName:(NSString*)name
{	
	for (Language* candidate in _languages)
	{
		if ([candidate.name isEqualToString:name])
			return candidate;
	}
	
	return nil;
}

+ (void)enumerate:(void (^)(Language* lang, bool* stop))block
{
	bool stop = false;
	for (Language* lang in _languages)
	{
		block(lang, &stop);
		if (stop)
			break;
	}
}

// This can be a bit expensive so a task would be kind of nice, but we'll
// almost always want to use the languages immediately so in practice
// loading them asynchronously won't help much.
+ (void)_processFiles
{
	ASSERT(_languages == nil);
	
	NSMutableArray* languages = [NSMutableArray new];
	
	NSString* dir = [Paths installedDir:@"languages"];
	Glob* glob = [[Glob alloc] initWithGlob:@"*.mimsy"];
	
	NSError* error = nil;
	[Utils enumerateDir:dir glob:glob error:&error block:
	 ^(NSString* item)
	 {
		 [self _processFile:item languages:languages];
	 }
	 ];
	if (error)
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load the language files at %@:\n%@.", dir, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
	}
	
	_languages = languages;
}

// This code would be clearer with goto, but goto often has problems when used with ARC.
+ (void)_processFile:(NSString*)path languages:(NSMutableArray*)languages
{
	Language* lang = nil;
	
	LOG_DEBUG("Styler", "Loading %s", STR([path lastPathComponent]));
	
	NSError* error = nil;
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (!error)
	{
		lang = [[Language alloc] initWithParser:parser outError:&error];
	}
	
	if (lang)
	{
		[languages addObject:lang];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load language %@:\n%@", path, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
	}
}

@end
