#import "StringCategory.h"

@implementation NSString (StringCategory)

- (bool)startsWith:(NSString*)needle
{
	NSRange range = [self rangeOfString:needle];
	return range.location == 0;
}

- (bool)endsWith:(NSString*)needle
{
	NSRange range = [self rangeOfString:needle options:NSBackwardsSearch];
	return range.location == self.length - needle.length;
}

- (bool)contains:(NSString*)needle
{
	NSRange range = [self rangeOfString:needle];
	return range.location != NSNotFound;
}

- (NSArray*)splitByString:(NSString*)separator
{
	NSArray* tmp = [self componentsSeparatedByString:separator];
	
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:tmp.count];
	for (NSString* s in tmp)
	{
		if (s.length > 0)
			[result addObject:s];
	}
	
	return result;
}

- (NSArray*)splitByChars:(NSCharacterSet*)chars
{
	NSArray* tmp = [self componentsSeparatedByCharactersInSet:chars];
	
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:tmp.count];
	for (NSString* s in tmp)
	{
		if (s.length > 0)
			[result addObject:s];
	}
	
	return result;
}

- (NSString*)titleCase
{
	NSString* result = self;
	
	if (result.length > 0)
	{
		NSString* prefix = [[self substringToIndex:1] uppercaseString];
		NSString* suffix = [self substringFromIndex:1];
		result = [prefix stringByAppendingString:suffix];
	}
	
	return result;
}

- (NSString*)map:(unichar (^)(unichar ch))block
{
	NSMutableString* result = [NSMutableString stringWithCapacity:self.length];
	
	for (NSUInteger i = 0; i < self.length; ++i)
	{
		[result appendFormat:@"%C", block([self characterAtIndex:i])];
	}
	
	return result;
}

@end
