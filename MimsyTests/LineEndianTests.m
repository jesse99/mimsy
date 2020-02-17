//#import "LineEndianTests.h"
//
//#import "TextDocument.h"
//
//@implementation LineEndianTests
//
//- (void)testNone
//{
//    const char* text = "";
//    TextDocument* doc = [self makeDocWithText:text];
//    STAssertEqualObjects([[doc text] string], [[NSString alloc] initWithUTF8String:text], nil);
//    STAssertEquals([doc endian], UnixEndian, nil);
//}
//
//- (void)testDefault
//{
//    const char* text = "hello world";
//    TextDocument* doc = [self makeDocWithText:text];
//    STAssertEqualObjects([[doc text] string], [[NSString alloc] initWithUTF8String:text], nil);
//    STAssertEquals([doc endian], UnixEndian, nil);
//}
//
//- (void)testUnix
//{
//    const char* text = "hello\nworld\n";
//    TextDocument* doc = [self makeDocWithText:text];
//    STAssertEqualObjects([[doc text] string], [[NSString alloc] initWithUTF8String:text], nil);
//    STAssertEquals([doc endian], UnixEndian, nil);
//}
//
//- (void)testMac
//{
//    const char* text = "hello\rworld\r";
//    TextDocument* doc = [self makeDocWithText:text];
//    STAssertEqualObjects([[doc text] string], [[NSString alloc] initWithUTF8String:"hello\nworld\n"], nil);
//    STAssertEquals([doc endian], MacEndian, nil);
//}
//
//- (void)testWindows
//{
//    const char* text = "hello\r\nworld\r\n";
//    TextDocument* doc = [self makeDocWithText:text];
//    STAssertEqualObjects([[doc text] string], [[NSString alloc] initWithUTF8String:"hello\nworld\n"], nil);
//    STAssertEquals([doc endian], WindowsEndian, nil);
//}
//
//- (void)testMixed
//{
//    const char* text = "hello\nworld\r\n\r\n";
//    TextDocument* doc = [self makeDocWithText:text];
//    STAssertEqualObjects([[doc text] string], [[NSString alloc] initWithUTF8String:"hello\nworld\n\n"], nil);
//    STAssertEquals([doc endian], WindowsEndian, nil);
//}
//
//- (TextDocument*) makeDocWithText:(const char*)text
//{
//    NSData* data = [NSData dataWithBytes:text length:strlen(text)];
//    TextDocument* doc = [TextDocument new];
//    NSError* error = nil;
//    BOOL result = [doc readFromData:data ofType:@"Plain Text, UTF8 Encoded" error:&error];
//    STAssertEquals(result, YES, nil);
//    STAssertNil(error, nil);
//    return doc;
//}
//
//@end
