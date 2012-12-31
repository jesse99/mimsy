#import "RegexStyler.h"

#import "Logger.h"
#import "StyleRuns.h"

@implementation RegexStyler
{
	NSRegularExpression* _regex;
	NSArray* _names;
}

- (id)initWithRegex:(NSRegularExpression*)regex elementNames:(NSArray*)names
{
	ASSERT(regex.numberOfCaptureGroups + 1 == names.count);
	
	_regex = regex;
	_names = names;
	return self;
}

// threaded
- (StyleRuns*)computeStyles:(NSString*)text editCount:(NSUInteger)count
{
	__block struct StyleRunVector runs = newStyleRunVector();
	reserveStyleRunVector(&runs, 2*text.length/40);	// this is how many runs I had in a screen of random rust code (x2 because of Default runs)
	
	__block NSUInteger lastMatch = 0;
	[_regex enumerateMatchesInString:text options:NSMatchingReportCompletion range:NSMakeRange(0, text.length) usingBlock:
		^(NSTextCheckingResult* match, NSMatchingFlags flags, BOOL* stop)
		{
			(void) flags;
			(void) stop;
			if (match.numberOfRanges > 0)
			{
				DEBUG_ASSERT(match.numberOfRanges == _names.count);
				for (NSUInteger i = 1; i < match.numberOfRanges; ++i)
				{
					NSRange range = [match rangeAtIndex:i];
					if (range.length > 0)
					{
						if (range.location > lastMatch)
							pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = 0, .range = NSMakeRange(lastMatch, range.location - lastMatch)});
							
						pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = i, .range = range});
						lastMatch = range.location + range.length;
						break;
					}
				}
			}
		}
	];
	
	if (lastMatch < text.length)
		pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = 0, .range = NSMakeRange(lastMatch, text.length - lastMatch)});

	return [[StyleRuns alloc] initWithElementNames:_names runs:runs editCount:count];
}

@end
