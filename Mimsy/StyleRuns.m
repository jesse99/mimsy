#import "StyleRuns.h"

@implementation StyleRuns
{
	NSArray* _names;
	NSArray* _styles;
	ElementToStyle _styler;
	struct StyleRunVector _runs;
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
	return _runs.count;
}

- (void)mapElementsToStyles:(ElementToStyle)block
{
	if (!_styler)
	{
		assert(!_styles);
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
		assert(_styler == block);	// can call mapElementsToStyles multiple times, but only with the same mapping
	}
}

- (void)process:(ProcessStyleRun)block
{
	assert(_styles);				// must call mapElementsToStyles at least once
	assert(_names.count == _styles.count);
	
	(void) block;
	
	bool stop = false;
	for (NSUInteger index = 0; index < _runs.count && !stop; ++index)
	{
		NSUInteger element = _runs.data[index].elementIndex;
		assert(element < _styles.count);
		block(_styles[element], _runs.data[index].range, &stop);
	}
}

@end
