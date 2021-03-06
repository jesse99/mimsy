//#import "RegexStylerTests.h"
//#import "RegexStyler.h"
//#import "StyleRuns.h"
//
//@implementation RegexStylerTests
//
//- (void)testBasics
//{
//#if 0
//    NSString* pattern = @"(if | else | for | while) | (' [^'\n]* ')";
//    NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;
//    
//    NSError* error = nil;
//    NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
//    STAssertNil(error, nil);
//    
//    struct UIntVector groupToName = newUIntVector();
//    pushUIntVector(&groupToName, 0);
//    pushUIntVector(&groupToName, 1);
//    pushUIntVector(&groupToName, 2);
//
////    RegexStyler* styler = [[RegexStyler alloc] initWithRegex:re elementNames:@[@"Normal", @"Keyword", @"String"] groupToName:groupToName];
////    StyleRuns* styleRuns = [styler computeStyles:@"if (blah) 'x' else 'y';" editCount:0];
//    
//    [styleRuns mapElementsToStyles:^id(NSString* elementName)
//     {
//         return [elementName stringByAppendingString:@" style"];
//     }];
//
//    NSMutableArray* styles = [NSMutableArray array];
//    NSMutableArray* locations = [NSMutableArray array];
//    [styleRuns process:^(NSUInteger elementIndex, id style, NSRange range, bool* stop)
//     {
//         [styles addObject:style];
//         [locations addObject:[NSNumber numberWithUnsignedLong:range.location]];
//     }];
//
//    // "if"            0
//    // " (blah) "    2
//    // "'x'"        10
//    // " "            13
//    // "else"        14
//    // " "            18
//    // "'y'"        19
//    // ";"            22
//
//    STAssertEquals(styles.count, (NSUInteger) 8, nil);
//    STAssertEquals(locations.count, (NSUInteger) 8, nil);
//    
//    // "if"            0
//    STAssertEqualObjects(styles[0], @"Keyword style", nil);
//    STAssertEqualObjects(locations[0], @0, nil);
//
//    // " (blah) "    2
//    STAssertEqualObjects(styles[1], @"Normal style", nil);
//    STAssertEqualObjects(locations[1], @2, nil);
//    
//    // "'x'"        10
//    STAssertEqualObjects(styles[2], @"String style", nil);
//    STAssertEqualObjects(locations[2], @10, nil);
//    
//    // " "            13
//    STAssertEqualObjects(styles[3], @"Normal style", nil);
//    STAssertEqualObjects(locations[3], @13, nil);
//    
//    // "else"        14
//    STAssertEqualObjects(styles[4], @"Keyword style", nil);
//    STAssertEqualObjects(locations[4], @14, nil);
//    
//    // " "            18
//    STAssertEqualObjects(styles[5], @"Normal style", nil);
//    STAssertEqualObjects(locations[5], @18, nil);
//    
//    // "'y'"        19
//    STAssertEqualObjects(styles[6], @"String style", nil);
//    STAssertEqualObjects(locations[6], @19, nil);
//
//    // ";"            22
//    STAssertEqualObjects(styles[7], @"Normal style", nil);
//    STAssertEqualObjects(locations[7], @22, nil);
//#endif
//}
//
//@end
