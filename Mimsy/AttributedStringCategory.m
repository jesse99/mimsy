#import "AttributedStringCategory.h"

#import "Assert.h"

@implementation NSMutableAttributedString (MutableAttributedStringCategory)

- (void)copyAttributes:(NSArray*)names from:(NSAttributedString*)from
{
	NSRange fullRange = NSMakeRange(0, from.string.length);
	for (NSString* name in names)
	{
		[from enumerateAttribute:name inRange:fullRange options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:
			 ^(id value, NSRange range, BOOL *stop)
			 {
				 UNUSED(stop);
				 if (value)
					 [self addAttribute:name value:value range:range];
			 }];
	}
}

@end
