#import "ColorTests.h"

#import "ColorCategory.h"

@implementation ColorTests

- (void)testNormalUsage
{
	NSColor* css = [NSColor colorWithCSS3Name:@"deepskyblue"];
	STAssertNotNil(css, nil);
	
	NSColor* vim = [NSColor colorWithVIMName:@"deepskyblue"];
	STAssertNotNil(vim, nil);
	
	NSColor* hex = [NSColor colorWithHex:@"#00BFFF"];
	STAssertNotNil(hex, nil);
	
	NSColor* decimal = [NSColor colorWithDecimal:@"(0, 191, 255)"];
	STAssertNotNil(decimal, nil);
	
	STAssertEqualObjects(css, vim, nil);
	STAssertEqualObjects(css, hex, nil);
	STAssertEqualObjects(css, decimal, nil);
}

- (void)testUnusualUsage
{
	NSColor* css = [NSColor colorWithCSS3Name:@" Deep Sky   Blue  "];
	STAssertNotNil(css, nil);
	
	NSColor* vim = [NSColor colorWithVIMName:@"Deep skyblue"];
	STAssertNotNil(vim, nil);
	
	NSColor* decimal = [NSColor colorWithDecimal:@" (00  ,  191  ,   255  )  "];
	STAssertNotNil(decimal, nil);
	
	STAssertEqualObjects(css, vim, nil);
	STAssertEqualObjects(css, decimal, nil);
}

- (void)testAlpha
{
	NSColor* hex = [NSColor colorWithHex:@"#00BFFF10"];
	STAssertNotNil(hex, nil);
	
	NSColor* decimal = [NSColor colorWithDecimal:@"(0, 191, 255, 16)"];
	STAssertNotNil(decimal, nil);
	
	STAssertEqualObjects(hex, decimal, nil);
	STAssertEquals((int) (255*hex.alphaComponent), 16, nil);
	STAssertEquals((int) (255*decimal.alphaComponent), 16, nil);
}

- (void)testBogus
{
	NSColor* css = [NSColor colorWithCSS3Name:@"zzz"];
	STAssertNil(css, nil);
	
	NSColor* vim = [NSColor colorWithVIMName:@"zzz"];
	STAssertNil(vim, nil);
	
	NSColor* hex = [NSColor colorWithHex:@"00BFFF"];
	STAssertNil(hex, nil);
	
	hex = [NSColor colorWithHex:@"#00BF"];
	STAssertNil(hex, nil);
	
	hex = [NSColor colorWithHex:@"#00BFFF1122"];
	STAssertNil(hex, nil);
	
	hex = [NSColor colorWithHex:@"#001ZFF"];
	STAssertNil(hex, nil);
	
	NSColor* decimal = [NSColor colorWithDecimal:@"(0, -191, 255)"];
	STAssertNil(decimal, nil);
	
	decimal = [NSColor colorWithDecimal:@"(0, 1919, 255)"];
	STAssertNil(decimal, nil);
	
	decimal = [NSColor colorWithDecimal:@"(0, 191, 255, 256)"];
	STAssertNil(decimal, nil);
	
	decimal = [NSColor colorWithDecimal:@"(0, 191,, 255)"];
	STAssertNil(decimal, nil);
	
	decimal = [NSColor colorWithDecimal:@"(0, 191, 255,)"];
	STAssertNil(decimal, nil);
	
	decimal = [NSColor colorWithDecimal:@"(0, 191, 255"];
	STAssertNil(decimal, nil);
}

@end
