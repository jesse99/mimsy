#import <Foundation/Foundation.h>

@interface NSArray (ArrayCategory)

// Returns a new array containing all elements for which the block returns true.
- (NSArray*)filteredArrayUsingBlock:(bool (^)(id element))block;

// Returns a new array with each element mapped using the block.
- (NSArray*)map:(id (^)(id element))block;

// Returns a new array with each element equal to object removed.
- (NSArray*)arrayByRemovingObject:(id)object;

- (NSArray*)arrayByRemovingObjects:(NSArray*)objects;

- (NSArray*)intersectArray:(NSArray*)rhs;

- (NSArray*)reverse;

@end

@interface NSMutableArray (MutableArrayCategory)

- (NSMutableArray*)map:(id (^)(id element))block;

@end
