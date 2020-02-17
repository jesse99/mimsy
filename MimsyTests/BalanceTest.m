//#import "BalanceTest.h"
//
//#import "Balance.h"
//
//#define STAssertEqualRanges(a1, a2) \
//    do \
//    { \
//        @try {\
//            NSRange a1value = (a1); \
//            NSRange a2value = (a2); \
//            if (!NSEqualRanges(a1value, a2value)) \
//            { \
//                [self failWithException:([NSException failureInFile:[NSString stringWithUTF8String:__FILE__] \
//                    atLine:__LINE__ \
//                    withDescription:[NSString stringWithFormat:@"%@ != %@", NSStringFromRange(a1value), NSStringFromRange(a2value)]])]; \
//            } \
//        }\
//        @catch (id anException) \
//        {\
//            [self failWithException:([NSException failureInRaise:[NSString stringWithFormat:@"%s == %s", #a1, #a2] \
//                exception:anException \
//                inFile:[NSString stringWithUTF8String:__FILE__] \
//                atLine:__LINE__ \
//                withDescription:@""])]; \
//        }\
//    } while(0)
//
//static bool isOpenBrace(NSString* text, NSUInteger index)
//{
//    unichar ch = [text characterAtIndex:index];
//    return ch == '(' || ch == '[' || ch == '{';
//}
//
//static bool isCloseBrace(NSString* text, NSUInteger index)
//{
//    unichar ch = [text characterAtIndex:index];
//    return ch == ')' || ch == ']' || ch == '}';
//}
//
//static int _balanceLeft(NSString* text, NSUInteger index)
//{
//    bool indexIsOpenBrace, indexIsCloseBrace, foundOtherBrace;
//    
//    bool (^isOpen)(NSUInteger)  = ^(NSUInteger index){return isOpenBrace(text, index);};
//    bool (^isClose)(NSUInteger) = ^(NSUInteger index){return isCloseBrace(text, index);};
//    
//    NSUInteger result = tryBalance(text, index, &indexIsOpenBrace, &indexIsCloseBrace, &foundOtherBrace, isOpen, isClose);
//    if (!indexIsCloseBrace)
//        return -2;
//    else if (!foundOtherBrace)
//        return -1;
//    else
//        return (int) result;
//}
//
//static int _balanceRight(NSString* text, NSUInteger index)
//{
//    bool indexIsOpenBrace, indexIsCloseBrace, foundOtherBrace;
//    
//    bool (^isOpen)(NSUInteger)  = ^(NSUInteger index){return isOpenBrace(text, index);};
//    bool (^isClose)(NSUInteger) = ^(NSUInteger index){return isCloseBrace(text, index);};
//    
//    NSUInteger result = tryBalance(text, index, &indexIsOpenBrace, &indexIsCloseBrace, &foundOtherBrace, isOpen, isClose);
//    if (!indexIsOpenBrace)
//        return -2;
//    else if (!foundOtherBrace)
//        return -1;
//    else
//        return (int) result;
//}
//
//static NSRange _balance(NSString* text, NSRange range)
//{
//    bool (^isOpen)(NSUInteger)  = ^(NSUInteger index){return isOpenBrace(text, index);};
//    bool (^isClose)(NSUInteger) = ^(NSUInteger index){return isCloseBrace(text, index);};
//    
//    return balance(text, range, isOpen, isClose);
//}
//
//@implementation BalanceTest
//
//- (void)testBalance
//{
//    STAssertEqualRanges(NSMakeRange(0, 0), _balance(@"hello", NSMakeRange(2, 0)));
//    
//    STAssertEqualRanges(NSMakeRange(0, 0), _balance(@"(hey)", NSMakeRange(0, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 5), _balance(@"(hey)", NSMakeRange(1, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 5), _balance(@"(hey)", NSMakeRange(2, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 5), _balance(@"(hey)", NSMakeRange(3, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 5), _balance(@"(hey)", NSMakeRange(4, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 0), _balance(@"(hey)", NSMakeRange(5, 0)));    // balanced range doesn't intersect the original range
//    
//    STAssertEqualRanges(NSMakeRange(0, 0), _balance(@"(hey])", NSMakeRange(1, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 0), _balance(@"(hey[)", NSMakeRange(1, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 7), _balance(@"(h[ey])", NSMakeRange(1, 0)));
//    
//    STAssertEqualRanges(NSMakeRange(0, 0), _balance(@"(())", NSMakeRange(0, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 4), _balance(@"(())", NSMakeRange(1, 0)));
//    STAssertEqualRanges(NSMakeRange(1, 2), _balance(@"(())", NSMakeRange(2, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 4), _balance(@"(())", NSMakeRange(3, 0)));
//    STAssertEqualRanges(NSMakeRange(0, 0), _balance(@"(())", NSMakeRange(4, 0)));
//    
//    STAssertEqualRanges(NSMakeRange(0, 13), _balance(@"(xx(yy) (zz))", NSMakeRange(8, 4)));
//    STAssertEqualRanges(NSMakeRange(0, 13), _balance(@"(xx(yy) (zz))", NSMakeRange(5, 5)));
//    
//    STAssertEqualRanges(NSMakeRange(0, 10), _balance(@"(foo(bar))", NSMakeRange(1,  2)));
//    STAssertEqualRanges(NSMakeRange(0, 10), _balance(@"(foo(bar))", NSMakeRange(4,  5)));
//    STAssertEqualRanges(NSMakeRange(0, 10), _balance(@"(foo(bar))", NSMakeRange(6,  4)));
//    
//    STAssertEqualRanges(NSMakeRange(0, 0), _balance(@"(hey[hey)", NSMakeRange(4, 5)));
//    
//    NSString* text = @"x(string text, NSRange range)y";
//    NSRange first = [text rangeOfString:@"("];
//    NSRange last = [text rangeOfString:@")"];
//    STAssertEqualRanges(NSMakeRange(first.location, text.length - 2), _balance(text, NSMakeRange(first.location + 1, 0)));
//    STAssertEqualRanges(NSMakeRange(first.location, text.length - 2), _balance(text, NSMakeRange(last.location, 0)));
//}
//
//- (void)testBalanceLeft
//{
//    STAssertEquals(-2, _balanceLeft(@"hello", 2), @"");
//    
//    STAssertEquals(-2, _balanceLeft(@"(hey)", 1), @"");
//    STAssertEquals(0, _balanceLeft(@"(hey)", 4), @"");
//    STAssertEquals(-1, _balanceLeft(@"(hey))", 5), @"");
//    STAssertEquals(0, _balanceLeft(@"((hey))", 6), @"");
//    STAssertEquals(1, _balanceLeft(@"((hey))", 5), @"");
//    
//    STAssertEquals(-1, _balanceLeft(@"((hey)]", 6), @"");
//    STAssertEquals(-1, _balanceLeft(@"([hey)]", 6), @"");
//    STAssertEquals(0, _balanceLeft(@"[(hey)]", 6), @"");
//    
//    STAssertEquals(0, _balanceLeft(@"[]", 1), @"");
//}
//
//- (void)testBalanceRight
//{
//    STAssertEquals(-2, _balanceRight(@"hello", 2), @"");
//    
//    STAssertEquals(-2, _balanceRight(@"(hey)", 4), @"");
//    STAssertEquals(4, _balanceRight(@"(hey)", 1), @"");
//    STAssertEquals(-1, _balanceRight(@"((hey)", 1), @"");
//    STAssertEquals(6, _balanceRight(@"((hey))", 1), @"");
//    STAssertEquals(5, _balanceRight(@"((hey))", 2), @"");
//    
//    STAssertEquals(-1, _balanceRight(@"[(hey))", 1), @"");
//    STAssertEquals(-1, _balanceRight(@"[(hey])", 1), @"");
//    STAssertEquals(6, _balanceRight(@"[(hey)]", 1), @"");
//}
//
//@end
