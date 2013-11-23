#import <Foundation/Foundation.h>

@interface NSArray (ArrayCategory)

// Returns a new array with each element mapped using the block.
- (NSArray*)map:(id (^)(id element))block;

// Returns a new array with each element equal to object removed.
- (NSArray*)arrayByRemovingObject:(id)object;

@end

@interface NSMutableArray (MutableArrayCategory)

- (NSMutableArray*)map:(id (^)(id element))block;

@end
