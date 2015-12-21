#import "FileSystemItem.h"

@implementation FileSystemItem
{
	MimsyPath* _standardPath;
}

- (id)initWithPath:(MimsyPath*)path controller:(DirectoryController*)controller
{
    self = [super init];
    if (self)
	{
		_path = path;
		_standardPath = [path standardize];
		_controller = controller;
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

- (NSAttributedString*) name
{
	ASSERT(false);
	return nil;
}

- (NSAttributedString*)bytes
{
	ASSERT(false);
	return nil;
}

- (NSString*)description
{
	return _path.description;
}

- (bool)reload:(NSMutableArray*)added
{
	(void) added;
	return false;
}

- (FileSystemItem*)find:(MimsyPath*)path
{
	return [_standardPath isEqualToPath:[path standardize]] ? self : nil;
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
