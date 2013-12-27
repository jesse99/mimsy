#import "ScannerCategory.h"

@implementation NSScanner (ScannerCategory)

- (BOOL)skip:(unichar)ch
{
	NSString* text = [self string];
	NSUInteger loc = [self scanLocation];
	if (loc < text.length && [text characterAtIndex:loc] == ch)
	{
		[self setScanLocation:loc + 1];
		return TRUE;
	}
	else
	{
		return FALSE;
	}
}

- (BOOL)scanLiteral:(NSString*)literal
{
	return [self scanString:literal intoString:NULL];
}

@end
