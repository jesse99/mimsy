#import "ApplyStyles.h"

#import "AsyncStyler.h"
#import "StyleRuns.h"
#import "TextController.h"
#import "TextStyles.h"

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

- (void)addDirtyLocation:(NSUInteger)loc
{
	if (!_queued)
	{
		// If nothing is queued then we can apply all the runs.
		_firstDirtyLoc = NSNotFound;
		_queued = true;
		
		[AsyncStyler computeStylesFor:_controller.language withText:_controller.text editCount:_controller.editCount completion:
			^(StyleRuns* runs)
			{
				[runs mapElementsToStyles:
					^id(NSString* name)
					{
						return [TextStyles attributesForElement:name];
					}
				];
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
	NSTextStorage* storage = _controller.textView.textStorage;
	
	[runs process:
		^(id style, NSRange range, bool* stop)
		{
			if (range.location + range.length < _firstDirtyLoc)
			{
				[self _applyStyle:style range:range storage:storage];
			}
			else
			{
				*stop = true;
			}
		}
	];
	
	_queued = false;
	if (_firstDirtyLoc != NSNotFound)
	{
		[self addDirtyLocation:_firstDirtyLoc];	// TODO: probably want to do this on a delay
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
