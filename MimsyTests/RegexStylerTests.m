#import "RegexStylerTests.h"
#import "RegexStyler.h"
#import "StyleRuns.h"

@implementation RegexStylerTests

- (void)testBasics
{
	NSString* pattern = @"(if | else | for | while) | (' [^'\n]* ')";
	NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;
	
	NSError* error = nil;
	NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
	STAssertNil(error, nil);
	
	RegexStyler* styler = [[RegexStyler alloc] initWithRegex:re elementNames:@[@"Keyword", @"String"]];
	StyleRuns* styleRuns = [styler computeStyles:@"if (blah) 'x' else 'y';" editCount:0];
	
	[styleRuns mapElementsToStyles:^id(NSString* elementName)
	 {
		 return [elementName stringByAppendingString:@" style"];
	 }];

	NSMutableArray* styles = [NSMutableArray array];
	NSMutableArray* locations = [NSMutableArray array];
	[styleRuns process:^(id style, NSRange range, bool* stop)
	 {
		 [styles addObject:style];
		 [locations addObject:[NSNumber numberWithUnsignedLong:range.location]];
	 }];

	STAssertEquals(styles.count, (NSUInteger) 4, nil);
	STAssertEquals(locations.count, (NSUInteger) 4, nil);
	
	STAssertEqualObjects(styles[0], @"Keyword style", nil);
	STAssertEqualObjects(locations[0], @0, nil);
	
	STAssertEqualObjects(styles[1], @"String style", nil);
	STAssertEqualObjects(locations[1], @10, nil);
	
	STAssertEqualObjects(styles[2], @"Keyword style", nil);
	STAssertEqualObjects(locations[2], @14, nil);
	
	STAssertEqualObjects(styles[3], @"String style", nil);
	STAssertEqualObjects(locations[3], @19, nil);
}

@end
