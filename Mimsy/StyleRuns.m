#import "StyleRuns.h"

@implementation StyleRuns
{
	NSArray* _names;
	NSArray* _styles;
	ElementToStyle _styler;
	struct StyleRunVector _runs;
	NSUInteger _processed;
	NSUInteger _oldOffset;
}

- (id)initWithElementNames:(NSArray*)names runs:(struct StyleRunVector)runs editCount:(NSUInteger)count
{
	_names = names;
	_styles = nil;		// set from the main thread via mapElementsToStyles
	_runs = runs;
	_editCount = count;
	return self;
}

- (void)dealloc
{
	freeStyleRunVector(&_runs);
}

- (NSUInteger)length
{
	DEBUG_ASSERT(_processed <= _runs.count);
	return _runs.count - _processed;
}

- (NSString*)indexToName:(NSUInteger)index
{
	return _names[index];
}

- (NSUInteger)nameToIndex:(NSString*)name
{
	for (NSUInteger i = 0; i < _names.count; ++i)
	{
		NSString* candidate = _names[i];
		if ([candidate compare:name options:NSCaseInsensitiveSearch] == NSOrderedSame)
			return i;
	}
	
	return NSNotFound;
}

- (void)mapElementsToStyles:(ElementToStyle)block
{
	if (!_styler)
	{
		ASSERT(!_styles);
		NSMutableArray* styles = [NSMutableArray arrayWithCapacity:_names.count];
		[_names enumerateObjectsUsingBlock:^(NSString* name, NSUInteger index, BOOL* stop)
		{
			(void) index;
			(void) stop;
			[styles addObject:block(name)];
		}];
		_styles = styles;
		_styler = block;
	}
	else
	{
		ASSERT(_styler == block);	// can call mapElementsToStyles multiple times, but only with the same mapping
	}
}

- (void)process:(ProcessStyleRun)block
{
	DEBUG_ASSERT(_styles);				// must call mapElementsToStyles at least once
	DEBUG_ASSERT(_names.count == _styles.count);
	
	bool stop = false;
	for (; _processed < _runs.count; ++_processed)
	{
		NSUInteger element = _runs.data[_processed].elementIndex;
		DEBUG_ASSERT(element < _styles.count);
		block(element, _styles[element], _runs.data[_processed].range, &stop);
		if (stop)
			break;		// run the block stopped on is not considered to be processed
	}
}

- (void)processIndexes:(ProcessStyleIndex)block
{
	bool stop = false;
	for (; _processed < _runs.count; ++_processed)
	{
		NSUInteger element = _runs.data[_processed].elementIndex;
		block(element, _runs.data[_processed].range, &stop);
		if (stop)
			break;		// run the block stopped on is not considered to be processed
	}
}

@end
