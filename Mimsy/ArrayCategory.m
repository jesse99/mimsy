#import "ArrayCategory.h"

@implementation NSArray (ArrayCategory)

- (NSArray*)filteredArrayUsingBlock:(bool (^)(id element))block
{
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count];
	
	for (id element in self)
	{
		if (block(element))
			[result addObject:element];
	}
	
	return result;
}

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
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count];
	
	for (id element in self)
	{
		if (![element isEqualTo:object])
			[result addObject:element];
	}
	
	return result;
}

- (NSArray*)arrayByRemovingObjects:(NSArray*)objects
{
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count];
	
	for (id element in self)
	{
		if (![objects containsObject:element])
			[result addObject:element];
	}
	
	return result;
}

- (NSArray*)reverse
{
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count];
	
	for (NSUInteger i = self.count - 1; i < self.count; --i)
	{
		id element = self[i];
		[result addObject:element];
	}
	
	return result;
}

- (NSArray*)intersectArray:(NSArray*)rhs
{
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count];
	
	for (NSUInteger i = 0; i < self.count; ++i)
	{
		id element = self[i];
		if ([rhs containsObject:element])
			[result addObject:element];
	}
	
	return result;
}

- (bool)startsWith:(NSArray*)rhs
{
	bool matches = self.count >= rhs.count;
	
	for (NSUInteger i = 0; i < rhs.count && matches; ++i)
	{
		matches = [self[i] isEqual:rhs[i]];
	}
	
	return matches;
}

@end

@implementation NSMutableArray (MutableArrayCategory)

- (NSMutableArray*)map:(id (^)(id element))block
{
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count];
	
	for (id element in self)
	{
		[result addObject:block(element)];
	}
	
	return result;
}

@end
