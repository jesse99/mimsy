#import "FileItem.h"

@implementation FileItem

- (id)initWithPath:(NSString*)path
{
	self = [super initWithPath:path];
	return self;
}

- (NSString*)bytes
{
	// TODO:
	// for packages we probably want to use a block
	// but would need some way to notify the view
	// maybe a single task could compute all the sizes
	return @"0";
}

@end
