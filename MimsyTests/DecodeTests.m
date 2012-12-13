#import "DecodeTests.h"

#import "Decode.h"

@implementation DecodeTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testEmpty
{
	const char* buffer = "";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:strlen(buffer)];
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"", nil);
	STAssertEquals([decode encoding], (unsigned long) NSUTF8StringEncoding, nil);
	STAssertNil([decode error], nil);
}

- (void)testAscii
{
	const char* buffer = "\x68\x65\x6c\x6c\x6f";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:strlen(buffer)];
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"hello", nil);
	STAssertEquals([decode encoding], (unsigned long) NSUTF8StringEncoding, nil);	// UTF-8 is a superset of 7-bit ASCII
	STAssertNil([decode error], nil);
}

- (void)testUtf8
{
	const char* buffer = "\x21\x3d\xe2\x80\xa2";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:strlen(buffer)];
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"!=\u2022", nil);
	STAssertEquals([decode encoding], (unsigned long) NSUTF8StringEncoding, nil);
	STAssertNil([decode error], nil);
}

- (void)testMacOsRoman
{
	const char* buffer = "\x21\x3d\xad";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:strlen(buffer)];
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"!=\u2260", nil);
	STAssertEquals([decode encoding], (unsigned long) NSMacOSRomanStringEncoding, nil);
	STAssertNil([decode error], nil);
}

- (void)testUtf16Big
{
	const char* buffer = "\x00\x21\x00\x3d\x22\x60";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:6];	// embedded nulls so can't use strlen
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"!=\u2260", nil);
	STAssertEquals([decode encoding], (unsigned long) NSUTF16BigEndianStringEncoding, nil);
	STAssertNil([decode error], nil);
}

- (void)testUtf16Little
{
	const char* buffer = "\x21\x00\x3d\x00\x60\x22";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:6];	// embedded nulls so can't use strlen
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"!=\u2260", nil);
	STAssertEquals([decode encoding], (unsigned long) NSUTF16LittleEndianStringEncoding, nil);
	STAssertNil([decode error], nil);
}

- (void)testUtf32Big
{
	const char* buffer = "\x00\x00\x00\x21\x00\x00\x00\x3d\x00\x00\x22\x60";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:12];	// embedded nulls so can't use strlen
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"!=\u2260", nil);
	STAssertEquals([decode encoding], (unsigned long) NSUTF32BigEndianStringEncoding, nil);
	STAssertNil([decode error], nil);
}

- (void)testUtf32Little
{
	const char* buffer = "\x21\x00\x00\x00\x3d\x00\x00\x00\x60\x22\x00\x00";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:12];	// embedded nulls so can't use strlen
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"!=\u2260", nil);
	STAssertEquals([decode encoding], (unsigned long) NSUTF32LittleEndianStringEncoding, nil);
	STAssertNil([decode error], nil);
}

- (void)testUtf32BigBOM
{
	const char* buffer = "\x00\x00\xFE\xFF\x00\x00\x00\x21\x00\x00\x00\x3d\x00\x00\x22\x60";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:16];	// embedded nulls so can't use strlen
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"!=\u2260", nil);
	STAssertEquals([decode encoding], (unsigned long) NSUTF32BigEndianStringEncoding, nil);
	STAssertNil([decode error], nil);
}

- (void)testUtf32LittleBOM
{
	const char* buffer = "\xFF\xFE\x00\x00\x21\x00\x00\x00\x3d\x00\x00\x00\x60\x22\x00\x00";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:16];	// embedded nulls so can't use strlen
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"!=\u2260", nil);
	STAssertEquals([decode encoding], (unsigned long) NSUTF32LittleEndianStringEncoding, nil);
	STAssertNil([decode error], nil);
}

@end
