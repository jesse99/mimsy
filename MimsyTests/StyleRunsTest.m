#import "StyleRunsTest.h"

#import "StyleRuns.h"

@implementation StyleRunsTest

- (StyleRuns*) createRuns
{
	struct StyleRunVector runs = newStyleRunVector();
	pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = 0, .range = NSMakeRange(0, 4)});
	pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = 0, .range = NSMakeRange(10, 2)});
	pushStyleRunVector(&runs, (struct StyleRun) {.elementIndex = 1, .range = NSMakeRange(20, 8)});
	
	NSArray* names = @[@"Keyword", @"String"];
	StyleRuns* styleRuns = [[StyleRuns new] initWithElementNames:names runs:runs editCount:0];
	STAssertEquals(styleRuns.length, (NSUInteger) 3, nil);
	
	[self processRun:styleRuns];
	[self processRun:styleRuns];	// real code calls mapElementsToStyles multiple times (which is OK if the same block is used)
	
	return styleRuns;
}

- (void) processRun:(StyleRuns*)runs
{
	[runs mapElementsToStyles:^id(NSString* elementName)
	 {
		 return [elementName stringByAppendingString:@" style"];
	 }];
}

- (void)testInitial
{
	StyleRuns* styleRuns = [self createRuns];
	
	NSMutableArray* styles = [NSMutableArray array];
	NSMutableArray* locations = [NSMutableArray array];
	[styleRuns process:^(NSUInteger elementIndex, id style, NSRange range, bool* stop)
	{
		[styles addObject:style];
		[locations addObject:[NSNumber numberWithUnsignedLong:range.location]];
	}];

	STAssertEqualObjects(styles[0], @"Keyword style", nil);
	STAssertEqualObjects(locations[0], @0, nil);
	
	STAssertEqualObjects(styles[1], @"Keyword style", nil);
	STAssertEqualObjects(locations[1], @10, nil);
	
	STAssertEqualObjects(styles[2], @"String style", nil);
	STAssertEqualObjects(locations[2], @20, nil);
}

@end
