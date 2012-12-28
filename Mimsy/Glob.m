#import "Glob.h"
#import <fnmatch.h>

@implementation Glob
{
	NSArray* _globs;
}

- (id)initWithGlob:(NSString*)glob
{
	_globs = [NSArray arrayWithObject:glob];
	return self;
}

- (id)initWithGlobs:(NSArray*)globs
{
	_globs = globs;
	return self;
}

- (bool)matchName:(NSString*)name
{
	for (NSString* glob in _globs)
	{
		if (fnmatch([glob UTF8String], [name UTF8String], FNM_CASEFOLD) == 0)
			return true;
	}
	return false;
}

@end
