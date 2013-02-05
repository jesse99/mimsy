#import "ApplyStyles.h"

#import "AsyncStyler.h"
#import "Logger.h"
#import "StartupScripts.h"
#import "StyleRuns.h"
#import "TextController.h"
#import "TextStyles.h"
#import "TextView.h"

// Syntax highlighting is difficult to do well. There are a number of competing factors
// that make it hard:
// 1) It has to be fast. There should be little or no degradation in typing speed even
// for large documents (say 5K lines of source). When the user stops typing styles
// should be rendered quickly (low tenths of seconds).
// 2) It needs to be correct. This gets especially obnoxious with stuff like strings
// which can span multiple lines.
// 3) The text cannot jump around as styles are applied.
// 4) It should be simple: it's much easier for problems to crop up with more complex
// code.
//
// Mimsy comes pretty close to meeting these goals. To a first apromiximation the order of
// operation is as follows:
// 1) When a text document with a language is changed ApplyStyles addDirtyLocation:reason:
// is called which queues up a concurrent task to associate all of the document's text
// with an element name and range.
// 2) ApplyStyles is called on the main thread with the run information.
// 3) ApplyStyles skips over any runs that were previously applied. This is much faster
// than re-applying them.
// 4) The new runs are applied from the top down using a 50ms window. Conceptually it would
// make more sense to sort the runs so that the runs closest to what the user is viewing are
// applied first, but that tends to cause the text to jump around when lines have differing
// heights.
// 5) If there are more runs to apply then queue up a block to execute on the main thread.
@implementation ApplyStyles
{
	__weak TextController* _controller;
	NSUInteger _firstDirtyLoc;
	struct StyleRunVector _appliedRuns;
	bool _queued;
}

- (id)init:(TextController*)controller
{
	_controller = controller;
	_appliedRuns = newStyleRunVector();
	return self;
}

- (void)resetStyles
{
	TextController* tmp = _controller;
	if (tmp)
	{
		NSTextStorage* storage = tmp.textView.textStorage;
		[storage setAttributes:[tmp.styles attributesForElement:@"Normal"] range:NSMakeRange(0, storage.length)];
		 
		[self addDirtyLocation:0 reason:@"reset styles"];
	}
}

- (void)addDirtyLocation:(NSUInteger)loc reason:(NSString*)reason
{
	TextController* tmp = _controller;
	if (tmp && !_queued)
	{
		// If nothing is queued then we can apply all the runs.
		_firstDirtyLoc = NSNotFound;
		_queued = true;
		LOG_DEBUG("Styler", "Starting up AsyncStyler for %.1f KiB (%s)", tmp.text.length/1024.0, STR(reason));
		
		[AsyncStyler computeStylesFor:tmp.language withText:tmp.text editCount:tmp.editCount completion:
			^(StyleRuns* runs)
			{
				TextController* tmp2 = _controller;
				if (tmp2)
				{
					[runs mapElementsToStyles:
						^id(NSString* name)
						{
							return [tmp2.styles attributesForElement:name];
						}
					];
					NSTextView* textv = tmp2.textView;
					if (textv)
						[textv setBackgroundColor:tmp2.styles.backColor];

					if (loc > 0)
						[self _skipApplied:runs];
					[self _applyRuns:runs];
				}
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

// This is about 50x faster than re-applying the runs.
- (void)_skipApplied:(StyleRuns*)runs
{
	double startTime = getTime();
	
	__block NSUInteger numApplied = 0;
	[runs process:
		 ^(NSUInteger elementIndex, id style, NSRange range, bool* stop)
		 {
			 if (numApplied < _appliedRuns.count &&
				 _appliedRuns.data[numApplied].elementIndex == elementIndex &&
				 _appliedRuns.data[numApplied].range.location == range.location &&
				 _appliedRuns.data[numApplied].range.length == range.length)
			 {
				 ++numApplied; 
			 }
			 else
			 {
				 setSizeStyleRunVector(&_appliedRuns, numApplied);
				 
				 TextController* tmp = _controller;
				 if (tmp)
				 {
					 NSTextStorage* storage = tmp.textView.textStorage;
					[self _applyStyle:style index:elementIndex range:range storage:storage];
				 }
				 *stop = true;
			 }
		 }
	 ];
	
	double elapsed = getTime() - startTime;
	LOG_DEBUG("Styler", "Skipped %lu runs (%.0fK runs/sec)", numApplied, (numApplied/1000.0)/elapsed);
}

- (void)_applyRuns:(StyleRuns*)runs
{
	// Corresponds to 4K runs on an early 2009 Mac Pro.
	const double MaxProcessTime = 0.050;
	
	TextController* tmp = _controller;
	if (tmp)
	{
		NSTextStorage* storage = tmp.textView.textStorage;
		double startTime = getTime();
			
		__block NSUInteger count = 0;
		__block NSUInteger beginLoc = 0;
		__block NSUInteger endLoc = 0;
		__block NSUInteger lastLoc = 0;
		[storage beginEditing];
		[runs process:
			^(NSUInteger elementIndex, id style, NSRange range, bool* stop)
			{
				(void) elementIndex;
				
				if (beginLoc == 0)
					beginLoc = range.location;
				
				lastLoc = range.location + range.length;
				if (lastLoc < _firstDirtyLoc)
				{
					[self _applyStyle:style index:elementIndex range:range storage:storage];
					endLoc = range.location + range.length;
					
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
		[StartupScripts invokeApplyStyles:tmp.document location:beginLoc length:endLoc-beginLoc];
		[storage endEditing];
		
		double elapsed = getTime() - startTime;
		if (lastLoc >= _firstDirtyLoc)
		{
			// If the user has done an edit there is a very good chance he'll do another
			// so defer queuing up another styler task.
			if (count > 0)
				LOG_DEBUG("Styler", "Applied %lu dirty runs (%.0fK runs/sec)", count, (count/1000.0)/elapsed);
			_queued = false;
			
			TextController* tmp = _controller;
				[tmp resetAttributes];
			
			dispatch_queue_t main = dispatch_get_main_queue();
			dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 100*1000);	// 0.1s
			dispatch_after(delay, main, ^{if (!_queued) [self addDirtyLocation:_firstDirtyLoc reason:@"still dirty"];});
		}
		else if (runs.length)
		{
			LOG_DEBUG("Styler", "Applied %lu runs (%.0fK runs/sec)", count, (count/1000.0)/elapsed);
			dispatch_queue_t main = dispatch_get_main_queue();
			dispatch_async(main, ^{[self _applyRuns:runs];});
		}
		else
		{
			LOG_DEBUG("Styler", "Applied last %lu runs (%.0fK runs/sec)", count, (count/1000.0)/elapsed);
			_queued = false;
		}
		if (count > 0)
			_applied = true;
	}
}

- (void)_applyStyle:(id)style index:(NSUInteger)index range:(NSRange)range storage:(NSTextStorage*)storage
{
	if (range.location + range.length > storage.length)	// can happen if the text is edited
		return;
	if (range.length == 0)
		return;
	
	pushStyleRunVector(&_appliedRuns, (struct StyleRun) {.elementIndex = index, .range = range});
	[storage addAttributes:style range:range];
}

@end
