//#import "VectorTests.h"
//
//#import "TestVector.h"
//
//@implementation VectorTests
//
//- (void)testCreate
//{
//    struct TestVector v = newTestVector();
//    STAssertEquals(v.count, (NSUInteger) 0, nil);
//    STAssertTrue(v.capacity > 0, nil);
//    
//    freeTestVector(&v);
//}
//
//// This will also test reserveTestVector (because MAX_SIZE is larger then
//// the default capacity).
//- (void)testPush
//{
//    const int MAX_SIZE = 32;
//    
//    struct TestVector v = newTestVector();
//    STAssertTrue(v.capacity < MAX_SIZE, nil);
//    
//    for (int i = 0; i < MAX_SIZE; ++i)
//    {
//        pushTestVector(&v, i);
//    }
//    
//    for (int i = 0; i < MAX_SIZE; ++i)
//    {
//        STAssertEquals(v.data[i], i, nil);
//    }
//    
//    freeTestVector(&v);
//}
//
//- (void)testPop
//{
//    struct TestVector v = newTestVector();
//    
//    pushTestVector(&v, 1);
//    pushTestVector(&v, 3);
//    pushTestVector(&v, 5);
//    
//    popTestVector(&v);
//    STAssertEquals(v.count, (NSUInteger) 2, nil);
//    STAssertEquals(v.data[0], 1, nil);
//    STAssertEquals(v.data[1], 3, nil);
//    
//    popTestVector(&v);
//    STAssertEquals(v.count, (NSUInteger) 1, nil);
//    STAssertEquals(v.data[0], 1, nil);
//    
//    popTestVector(&v);
//    STAssertEquals(v.count, (NSUInteger) 0, nil);
//    
//    freeTestVector(&v);
//}
//
//- (void)testInsertAt
//{
//    struct TestVector v = newTestVector();
//    
//    insertAtTestVector(&v, 0, 3);
//    insertAtTestVector(&v, 0, 5);
//    STAssertEquals(v.count, (NSUInteger) 2, nil);
//    STAssertEquals(v.data[0], 5, nil);
//    STAssertEquals(v.data[1], 3, nil);
//    
//    insertAtTestVector(&v, 1, 7);
//    STAssertEquals(v.count, (NSUInteger) 3, nil);
//    STAssertEquals(v.data[0], 5, nil);
//    STAssertEquals(v.data[1], 7, nil);
//    STAssertEquals(v.data[2], 3, nil);
//    
//    freeTestVector(&v);
//}
//
//- (void)testRemoveAt
//{
//    struct TestVector v = newTestVector();
//    
//    pushTestVector(&v, 1);
//    pushTestVector(&v, 3);
//    pushTestVector(&v, 5);
//    
//    removeAtTestVector(&v, 1);
//    STAssertEquals(v.count, (NSUInteger) 2, nil);
//    STAssertEquals(v.data[0], 1, nil);
//    STAssertEquals(v.data[1], 5, nil);
//    
//    removeAtTestVector(&v, 0);
//    STAssertEquals(v.count, (NSUInteger) 1, nil);
//    STAssertEquals(v.data[0], 5, nil);
//    
//    removeAtTestVector(&v, 0);
//    STAssertEquals(v.count, (NSUInteger) 0, nil);
//    
//    freeTestVector(&v);
//}
//
//@end
