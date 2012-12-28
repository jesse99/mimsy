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

- (void)sortByDistanceFrom:(NSUInteger)offset threshold:(NSUInteger)threshold
{
	// Only sort if the new offset is significantly different from the previous
	// offset (there's no point in re-sorting runs when the user scrolls by a line
	// or two).
	if (offset != _oldOffset && abs((int) _oldOffset - (int) offset) > threshold)
	{
		// mergesort because it's expected that the runs will usually be more or less sorted already
		mergesort_b(_runs.data, _runs.count, sizeof(struct StyleRun),
			^(const void* lhs, const void* rhs)
			{
				const struct StyleRun* run1 = (const struct StyleRun*) lhs;
				const struct StyleRun* run2 = (const struct StyleRun*) rhs;
				int delta1 = abs((int) run1->range.location - (int) offset);
				int delta2 = abs((int) run2->range.location - (int) offset);
				if (delta1 < delta2)
					return -1;
				else if (delta1 > delta2)
					return 1;
				else
					return 0;
			}
		);
		
		_oldOffset = offset;
	}
}

@end
