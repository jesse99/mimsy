#import "StringCategory.h"

#import "ArrayCategory.h"

@implementation NSString (StringCategory)

+ (NSString*)stringWithN:(NSUInteger)count instancesOf:(NSString*)token
{
	NSMutableString* str = [NSMutableString stringWithCapacity:count*token.length];
	
	for (NSUInteger i = 0; i < count; ++i)
		[str appendString:token];
	
	return str;
}

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

- (bool)containsChar:(unichar)ch
{
	for (NSUInteger i = 0; i < self.length; ++i)
	{
		if ([self characterAtIndex:i] == ch)
			return true;
	}
	
	return false;
}

- (NSString*)reversePath
{
	NSArray* components = [self splitByString:@"/"];
	NSArray* reversed = [components reverse];
	return [reversed componentsJoinedByString:@"\u2009\u2022\u2009"];	// thin space, bullet, thin space
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

- (NSString*)replaceCharacters:(NSString*)chars with:(NSString*)with
{
	NSMutableString* result = [NSMutableString stringWithCapacity:self.length];
	
	for (NSUInteger i = 0; i < self.length; ++i)
	{
		unichar ch = [self characterAtIndex:i];
		
		if ([chars containsChar:ch])
			[result appendString:with];
		else
			[result appendFormat:@"%C", ch];
	}
	
	return result;
}

@end
