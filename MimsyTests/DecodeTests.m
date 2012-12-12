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
	STAssertEquals([decode encoding], NSUTF8StringEncoding, nil);
	STAssertNil([decode error], nil);
}

- (void)testAscii
{
	const char* buffer = "\x68\x65\x6c\x6c\x6f";
	NSData* data = [[NSData alloc] initWithBytes:buffer length:strlen(buffer)];
	
	Decode* decode = [[Decode alloc] initWithData:data];
	STAssertEqualObjects([decode text], @"hello", nil);
	STAssertEquals([decode encoding], NSUTF8StringEncoding, nil);	// UTF-8 is a superset of 7-bit ASCII
	STAssertNil([decode error], nil);
}

@end

//NSASCIIStringEncoding = 1,
//NSNEXTSTEPStringEncoding = 2,
//NSJapaneseEUCStringEncoding = 3,
//NSUTF8StringEncoding = 4,
//NSISOLatin1StringEncoding = 5,
//NSSymbolStringEncoding = 6,
//NSNonLossyASCIIStringEncoding = 7,
//NSShiftJISStringEncoding = 8,
//NSISOLatin2StringEncoding = 9,
//NSUnicodeStringEncoding = 10,
//NSWindowsCP1251StringEncoding = 11,
//NSWindowsCP1252StringEncoding = 12,
//NSWindowsCP1253StringEncoding = 13,
//NSWindowsCP1254StringEncoding = 14,
//NSWindowsCP1250StringEncoding = 15,
//NSISO2022JPStringEncoding = 21,
//NSMacOSRomanStringEncoding = 30,
//NSUTF16StringEncoding = NSUnicodeStringEncoding,
//NSUTF16BigEndianStringEncoding = 0x90000100,
//NSUTF16LittleEndianStringEncoding = 0x94000100,
//NSUTF32StringEncoding = 0x8c000100,
//NSUTF32BigEndianStringEncoding = 0x98000100,
//NSUTF32LittleEndianStringEncoding = 0x9c000100,
//NSProprietaryStringEncoding = 65536
