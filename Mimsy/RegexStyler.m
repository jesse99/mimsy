#import "RegexStyler.h"

#import "Logger.h"
#import "StyleRuns.h"

@implementation RegexStyler
{
	NSRegularExpression* _regex;
	struct UIntVector _groupToName;
}

- (id)initWithRegex:(NSRegularExpression*)regex elementNames:(NSArray*)names groupToName:(struct UIntVector)map
{
	ASSERT(regex.numberOfCaptureGroups + 1 >= names.count);
	
	_regex = regex;
	_names = names;
	_groupToName = map;
	
	return self;
}

- (void)dealloc
{
	freeUIntVector(&_groupToName);
}

// threaded
- (StyleRuns*)computeStyles:(NSString*)text editCount:(NSUInteger)count
{
	__block struct StyleRunVector runs = newStyleRunVector();
	reserveStyleRunVector(&runs, 2*text.length/40);	// this is how many runs I had in a screen of random rust code (x2 because of Normal runs)
	
	__block NSUInteger lastMatch = 0;
	[_regex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:
		^(NSTextCheckingResult* match, NSMatchingFlags flags, BOOL* stop)
		{
			(void) flags;
			(void) stop;
			if (match.numberOfRanges > 0)
			{
				DEBUG_ASSERT(match.numberOfRanges == _groupToName.count);
				
				// We use the smallest non-zero range as a work around for the lack
				// of unbounded look-behind asserts.
				NSUInteger index = NSIntegerMax;
				NSRange range = NSMakeRange(0, NSIntegerMax);
				for (NSUInteger i = 1; i < match.numberOfRanges; ++i)
				{
					NSRange candidate = [match rangeAtIndex:i];
					if (candidate.length > 0 && candidate.length < range.length)
					{
						DEBUG_ASSERT(i < _groupToName.count);
						NSUInteger elementIndex = _groupToName.data[i];
						DEBUG_ASSERT(elementIndex < _names.count);
						
//						LOG_INFO("Styler", "Matched %s (%lu) at [%lu, %lu)",
//							STR(_names[elementIndex]), elementIndex, candidate.location, candidate.length);
						if (index == NSIntegerMax)
						{
							index = elementIndex;
							range = candidate;
						}
						else if (index == elementIndex)
						{
							range = candidate;
						}
						else
						{
							LOG_WARN("Styler", "'%s' matched %s and %s",
								STR([text substringWithRange:candidate]), STR(_names[index]), STR(_names[elementIndex]));
						}
					}
				}
				if (index < NSIntegerMax)
				{
					if (range.location > lastMatch)
						pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = 0, .range = NSMakeRange(lastMatch, range.location - lastMatch)});
					
					pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = index, .range = range});
					lastMatch = range.location + range.length;
				}
			}
		}
	];
	
	if (lastMatch < text.length)
		pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = 0, .range = NSMakeRange(lastMatch, text.length - lastMatch)});

	return [[StyleRuns alloc] initWithElementNames:_names runs:runs editCount:count];
}

@end
