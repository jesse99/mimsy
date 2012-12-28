#import "RegexStyler.h"

#import "StyleRuns.h"

@implementation RegexStyler
{
	NSRegularExpression* _regex;
	NSArray* _names;
}

- (id)initWithRegex:(NSRegularExpression*)regex elementNames:(NSArray*)names
{
	assert(regex.numberOfCaptureGroups == names.count);
	
	_regex = regex;
	_names = names;
	return self;
}

// threaded
- (StyleRuns*)computeStyles:(NSString*)text editCount:(NSUInteger)count
{
	__block struct StyleRunVector runs = newStyleRunVector();
	reserveStyleRunVector(&runs, text.length/40);	// this is how many runs I had in a screen of random rust code
	
	[_regex enumerateMatchesInString:text options:NSMatchingReportCompletion range:NSMakeRange(0, text.length) usingBlock:
		^(NSTextCheckingResult* match, NSMatchingFlags flags, BOOL* stop)
		{
			(void) flags;
			(void) stop;
			if (match.numberOfRanges > 0)
			{
				assert(match.numberOfRanges == _names.count + 1);
				for (NSUInteger i = 1; i < match.numberOfRanges; ++i)
				{
					NSRange range = [match rangeAtIndex:i];
					if (range.length > 0)
					{
						pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = i - 1, .range = range});
						break;
					}
				}
			}
		}
	];
	
	return [[StyleRuns alloc] initWithElementNames:_names runs:runs editCount:count];
}

@end
