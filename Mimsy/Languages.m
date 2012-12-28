#import "Languages.h"

@implementation Languages
{

}

+ (void)setup
{
	
}

+ (RegexStyler*)findStylerWithFileName:(NSString*)name text:(NSString*)text
{
	(void) name;
	(void) text;
	return nil;
}

@end

// TODO:
// _globs	NSArray of glob objects, these should support conditional globs (or a subclass?)
// _stylers	NSArray of RegexStyler
