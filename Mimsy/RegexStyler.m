#import "RegexStyler.h"

#import "StyleRuns.h"

@implementation RegexStyler
{
	NSRegularExpression* _regex;
	NSArray* _elementNames;
}

- (id)initWithRegex:(NSRegularExpression*)regex andElements:(NSArray*)names
{
	assert(regex.numberOfCaptureGroups == names.count);
	
	_regex = regex;
	_elementNames = names;
	return self;
}

// threaded
- (StyleRuns*)computeStyles:(NSString*)text editCount:(NSUInteger)count
{
	(void) text;
	(void) count;
	return nil;
}

@end

// TODO:
// use some heuristic to set initial capacity
