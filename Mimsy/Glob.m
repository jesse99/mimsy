#import "Glob.h"
#import <fnmatch.h>

@implementation Glob

- (BOOL)matches:(MimsyPath*)path
{
    return [self matchName:path.asString] == 1;
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

- (int)matchName:(NSString*)name
{
	for (NSString* glob in _globs)
	{
		if (fnmatch([glob UTF8String], [name UTF8String], FNM_CASEFOLD) == 0)
			return 1;
	}
	return 0;
}

- (int)matchStr:(const char*)name
{
	for (NSString* glob in _globs)
	{
		if (fnmatch([glob UTF8String], name, FNM_CASEFOLD) == 0)
			return 1;
	}
	return 0;
}

- (id)copyWithZone:(NSZone*)zone
{
	return [[Glob allocWithZone:zone] initWithGlobs:_globs];
}

- (NSUInteger)hash
{
	return [_globs hash];
}

- (BOOL)isEqual:(id)rhs
{
	if (rhs && [rhs isMemberOfClass:[Glob class]])
	{
		Glob* g = (Glob*) rhs;
		return [_globs isEqual:g.globs];
	}
	return FALSE;
}

- (NSString*)description
{
	if (_globs.count == 1)
	{
		return [_globs[0] description];
	}
	else
	{
		return [_globs componentsJoinedByString:@";"];
	}

}
@end
