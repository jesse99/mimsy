#import "ConditionalGLobTests.h"
#import "ConditionalGLob.h"

@implementation ConditionalGLobTests

- (void)testSimple
{
	ConditionalGlob* glob = [[ConditionalGlob alloc] initWithGlob:@"f[oe][oe].*"];
	STAssertEquals([glob matchName:@"foo.txt"], 1, nil);
	STAssertEquals([glob matchName:@"foo.txt" contents:@"blah"], 1, nil);
	
	STAssertEquals([glob matchName:@"fee.rtf"], 1, nil);
	STAssertEquals([glob matchName:@"fee.rtf" contents:@"blah"], 1, nil);

	STAssertEquals([glob matchName:@"goo.txt"], 0, nil);
	STAssertEquals([glob matchName:@"goo.txt" contents:@"blah"], 0, nil);
}

- (void)testConditional
{
	NSArray* globs = @[@"*.m"];
	NSArray* conditionals = @[@"*.h", @"*.x"];

	NSError* error = nil;
	NSMutableArray* regexen = [NSMutableArray new];
	NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:@"@end|NSObject" options:0 error:&error];
	STAssertNil(error, nil);
	[regexen addObject:re];
	[regexen addObject:re];

	ConditionalGlob* glob = [[ConditionalGlob alloc] initWithGlobs:globs regexen:regexen conditionals:conditionals];
	
	STAssertEquals([glob matchName:@"foo.h"], 0, nil);
	STAssertEquals([glob matchName:@"foo.m"], 1, nil);
	STAssertEquals([glob matchName:@"foo.cpp"], 0, nil);
	
	STAssertEquals([glob matchName:@"foo.h" contents:@"// a C file"], 0, nil);
	STAssertEquals([glob matchName:@"foo.h" contents:@"// an objc file\n@interface foo\n@end\n"], 2, nil);
	STAssertEquals([glob matchName:@"foo.m" contents:@"// an objc file"], 1, nil);
	STAssertEquals([glob matchName:@"foo.cpp" contents:@"// a C++ file"], 0, nil);
}

@end
