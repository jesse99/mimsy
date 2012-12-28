#import "ConditionalGLobTests.h"
#import "ConditionalGLob.h"

@implementation ConditionalGLobTests

- (void)testSimple
{
	ConditionalGlob* glob = [[ConditionalGlob alloc] initWithGlob:@"f[oe][oe].*"];
	STAssertTrue([glob matchName:@"foo.txt"], nil);
	STAssertTrue([glob matchName:@"foo.txt" contents:@"blah"], nil);
	
	STAssertTrue([glob matchName:@"fee.rtf"], nil);
	STAssertTrue([glob matchName:@"fee.rtf" contents:@"blah"], nil);

	STAssertFalse([glob matchName:@"goo.txt"], nil);
	STAssertFalse([glob matchName:@"goo.txt" contents:@"blah"], nil);
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
	
	STAssertFalse([glob matchName:@"foo.h"], nil);
	STAssertTrue([glob matchName:@"foo.m"], nil);
	STAssertFalse([glob matchName:@"foo.cpp"], nil);
	
	STAssertFalse([glob matchName:@"foo.h" contents:@"// a C file"], nil);
	STAssertTrue([glob matchName:@"foo.h" contents:@"// an objc file\n@interface foo\n@end\n"], nil);
	STAssertTrue([glob matchName:@"foo.m" contents:@"// an objc file"], nil);
	STAssertFalse([glob matchName:@"foo.cpp" contents:@"// a C++ file"], nil);
}

@end
