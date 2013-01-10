#import "ArrayCategory.h"

@implementation NSArray (ArrayCategory)

- (NSArray*)map:(id (^)(id element))block
{
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count];
	
	for (id element in self)
	{
		[result addObject:block(element)];
	}
	
	return result;
}

- (NSArray*)arrayByRemovingObject:(id)object
{
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count - 1];
	
	for (id element in self)
	{
		if (![element isEqualTo:object])
			[result addObject:element];
	}
	
	return result;
}

@end
