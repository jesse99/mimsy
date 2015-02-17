#import "RegexStyler.h"

#import "Logger.h"
#import "StyleRuns.h"

@implementation RegexStyler
{
	NSArray* _regexen;
    NSArray* _names;    // zero is "normal", one is for _regexen[0]
}

- (id)initWithRegexen:(NSArray*)regexen elementNames:(NSArray*)names
{
	ASSERT(regexen.count >= names.count - 1);
	
	_regexen = regexen;
	_names = names;
	
	return self;
}

// threaded
static int compareRun(const void* inLhs, const void* inRhs)
{
    const struct StyleRun* lhs = (const struct StyleRun*) inLhs;
    const struct StyleRun* rhs = (const struct StyleRun*) inRhs;
    
    if (lhs->range.location < rhs->range.location)
        return -1;
    else if (lhs->range.location > rhs->range.location)
        return +1;
    
    if (lhs->range.length < rhs->range.length)
        return -1;
    else if (lhs->range.length > rhs->range.length)
        return +1;
    
    return 0;
}

// threaded
static int compareIntersections(const void* inLhs, const void* inRhs)
{
    const struct StyleRun* lhs = (const struct StyleRun*) inLhs;
    const struct StyleRun* rhs = (const struct StyleRun*) inRhs;
    
    NSUInteger left = lhs->range.location;
    NSUInteger right = lhs->range.location + lhs->range.length;
    
    if (right < rhs->range.location)
        return -1;
    else if (left > rhs->range.location + rhs->range.length)
        return +1;
    
    return 0;
}

// threaded
- (StyleRuns*)computeStyles:(NSString*)text editCount:(NSUInteger)count
{
	__block struct StyleRunVector runs = newStyleRunVector();
	reserveStyleRunVector(&runs, 2*text.length/40);	// this is how many runs I had in a screen of random rust code (x2 because of Normal runs)
    
    for (NSUInteger i = 0; i < _regexen.count; ++i)
    {
        NSRegularExpression* re = _regexen[i];
        [self _matchRegex:re runs:&runs index:i text:text];
    }
    
    [self _insertNormalStyles:&runs text:text];
		
	return [[StyleRuns alloc] initWithElementNames:_names runs:runs editCount:count];
}

// threaded
- (void) _matchRegex:(NSRegularExpression*)re runs:(struct StyleRunVector*)runs index:(NSUInteger)index text:(NSString*)text
{
    NSUInteger count = runs->count;
    [re enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:
     ^(NSTextCheckingResult* match, NSMatchingFlags flags, BOOL* stop)
     {
         (void) flags;
         (void) stop;
         
         NSRange range = re.numberOfCaptureGroups == 0 ? [match rangeAtIndex:0] : [match rangeAtIndex:1];
         struct StyleRun run = {.elementIndex = index+1, .range = range};
         
         struct StyleRun* intersects = (struct StyleRun*) bsearch(&run, runs->data, count, sizeof(struct StyleRun), compareIntersections);
         if (!intersects)
             pushStyleRunVector(runs, run);
     }
     ];

    // Haven't measured this but I think it's faster to append to the end and then sort
    // rather than inserting possibly lots of runs in the correct location.
    qsort(runs->data, runs->count, sizeof(struct StyleRun), compareRun);
}

// threaded
- (void) _insertNormalStyles:(struct StyleRunVector*)runs text:(NSString*)text
{
    NSUInteger count = runs->count;

    NSUInteger location = 0;
    for (NSUInteger i = 0; i < count; ++i)
    {
        if (location < runs->data[i].range.location)
            pushStyleRunVector(runs, (struct StyleRun) {.elementIndex = 0, .range = NSMakeRange(location, runs->data[i].range.location - location)});
        location = runs->data[i].range.location + runs->data[i].range.length;
    }

    if (count > 0)
    {
        NSUInteger lastLocation = runs->data[count-1].range.location + runs->data[count-1].range.length;
        if (lastLocation < text.length)
        {
            pushStyleRunVector(runs, (struct StyleRun) {.elementIndex = 0, .range = NSMakeRange(lastLocation, text.length - lastLocation)});
        }
    }

    qsort(runs->data, runs->count, sizeof(struct StyleRun), compareRun);
}

@end

