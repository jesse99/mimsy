#import "FileSystemItem.h"

#import "Assert.h"

@implementation FileSystemItem
{
	NSString* _standardPath;
}

- (id)initWithPath:(NSString*)path
{
    self = [super init];
    if (self)
	{
		_name = [path lastPathComponent];
		_path = path;
		_standardPath = [path stringByStandardizingPath];
    }
    return self;
}

- (bool)isExpandable
{
	return false;
}

- (NSUInteger)count
{
	return 0;
}

- (FileSystemItem*)objectAtIndexedSubscript:(NSUInteger)index
{
	(void) index;
	
	ASSERT_MESG("Need to override objectAtIndexedSubscript in order to subscript the file item");
	return nil;
}

- (NSString*)bytes
{
	return @"";
}

- (NSString*)description
{
	return _path;
}

- (bool)reload:(NSMutableArray*)added
{
	(void) added;
	return false;
}

- (BOOL)isEqual:(id)rhs
{
	if (rhs && [rhs isKindOfClass:[FileSystemItem class]])
	{
		FileSystemItem* item = (FileSystemItem*) rhs;
		return _standardPath == item->_standardPath;
	}
	return FALSE;
}

- (NSUInteger)hash
{
	return [_standardPath hash];
}

@end
