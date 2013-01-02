#import "ApplyStyles.h"

#import "AsyncStyler.h"
#import "Logger.h"
#import "StyleRuns.h"
#import "TextController.h"
#import "TextStyles.h"
#import "TextView.h"

@implementation ApplyStyles
{
	TextController* _controller;
	NSUInteger _firstDirtyLoc;
	bool _queued;
}

- (id)init:(TextController*)controller
{
	_controller = controller;
	return self;
}

- (void)addDirtyLocation:(NSUInteger)loc reason:(NSString*)reason
{
	if (!_queued)
	{
		// If nothing is queued then we can apply all the runs.
		_firstDirtyLoc = NSNotFound;
		_queued = true;
		LOG_DEBUG("Text", "Starting up AsyncStyler for %.1f KiB (%s)", _controller.text.length/1024.0, STR(reason));
		
		[AsyncStyler computeStylesFor:_controller.language withText:_controller.text editCount:_controller.editCount completion:
			^(StyleRuns* runs)
			{
				[runs mapElementsToStyles:
					^id(NSString* name)
					{
						return [TextStyles attributesForElement:name];
					}
				];
				[_controller.textView setBackgroundColor:[TextStyles backColor]];
				[self _applyRuns:runs];
			}
		 ];
	}
	else
	{
		// Otherwise we can usually apply the runs up to the dirty location.
		// The exception is stuff like the user typing the end delimiter of
		// a string. In that case the queued up apply will fail for the last
		// bit of text, but because _firstDirtyLoc is set we'll cycle back
		// around to here once we hit the dirty location and fix things up
		// then.
		_firstDirtyLoc = MIN(loc, _firstDirtyLoc);
	}
}

- (void)_applyRuns:(StyleRuns*)runs
{
	// Corresponds to 4K runs on an early 2009 Mac Pro.
	const double MaxProcessTime = 0.050;
	
	NSTextStorage* storage = _controller.textView.textStorage;
	double startTime = getTime();
	
	__block NSUInteger count = 0;
	__block NSUInteger lastLoc = 0;
	[storage beginEditing];
	[runs process:
		^(id style, NSRange range, bool* stop)
		{
			lastLoc = range.location + range.length;
			if (lastLoc < _firstDirtyLoc)
			{
				[self _applyStyle:style range:range storage:storage];
				
				if (++count % 1000 == 0 && (getTime() - startTime) > MaxProcessTime)
				{
					*stop = true;
				}
			}
			else
			{
				*stop = true;
			}
		}
	];
	[storage endEditing];
	
	double elapsed = getTime() - startTime;
	if (lastLoc >= _firstDirtyLoc)
	{
		// If the user has done an edit there is a very good chance he'll do another
		// so defer queuing up another styler task.
		LOG_DEBUG("Text", "Applied %lu dirty runs (%.0f runs/sec)", count, count/elapsed);
		_queued = false;
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 100*1000);	// 0.1s
		dispatch_after(delay, main, ^{if (!_queued) [self addDirtyLocation:_firstDirtyLoc reason:@"still dirty"];});
	}
	else if (runs.length)
	{
		LOG_DEBUG("Text", "Applied %lu runs (%.0f runs/sec)", count, count/elapsed);
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_async(main, ^{[self _applyRuns:runs];});
	}
	else
	{
		LOG_DEBUG("Text", "Applied last %lu runs (%.0f runs/sec)", count, count/elapsed);
		_queued = false;
	}
}

- (void)_applyStyle:(id)style range:(NSRange)range storage:(NSTextStorage*)storage
{
	if (range.location + range.length > storage.length)	// can happen if the text is edited
		return;
	if (range.length == 0)
		return;
	
	[storage addAttributes:style range:range];
}

@end
