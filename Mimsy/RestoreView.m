#import "RestoreView.h"

#import "Logger.h"
#import "TextController.h"
#import "TextView.h"
#import "Utils.h"
#import "WindowsDatabase.h"

@implementation RestoreView
{
	__weak TextController* _controller;
	struct WindowInfo _info;
	NSRange _visible;
	NSRange _deferred;
}

- (id)init:(TextController*)controller
{
	_controller = controller;
	_info.length = -1;
	return self;
}

- (void)setPath:(NSString*)path
{
	if (path)
	{
		if ([WindowsDatabase getInfo:&_info forPath:path])
		{
			if (_info.wordWrap)
			{
				TextController* tmp = _controller;
				if (tmp)
					[tmp toggleWordWrap];
			}
		}
	}
}

- (void)showLineBegin:(NSUInteger)begin end:(NSUInteger)end count:(NSUInteger)count
{
	_info.length = -1;
	_info.origin = NSZeroPoint;
	_info.selection = NSMakeRange(begin, 0);
	_visible = NSMakeRange(begin, end - begin);
	_deferred = NSMakeRange(begin, count);
}

- (void)showSelection:(NSRange)range
{
	_info.length = -1;
	_info.origin = NSZeroPoint;
	_info.selection = range;
	_visible = range;
	_deferred = range;
}

- (bool)onCompletedLayout:(NSLayoutManager*)layout atEnd:(bool)atEnd
{
	bool finished = false;
	
	if (atEnd || (NSEqualPoints(_info.origin, NSZeroPoint) && [layout firstUnlaidCharacterIndex] > _info.selection.location + 100))
	{
		TextController* controller = _controller;
		if (controller)
		{
			NSScrollView* scrollerv = controller.scrollView;
			TextView* textv = controller.textView;
			if (_info.length == -1 || _info.length == controller.text.length)	// only restore the view if it has not changed since we last had it open
			{
				NSClipView* clip = scrollerv.contentView;
				NSPoint origin = clip.bounds.origin;
				if (NSEqualPoints(origin, NSZeroPoint) || textv.restored)		// don't scroll if the user has already scrolled
				{
					if (!NSEqualPoints(_info.origin, NSZeroPoint))
					{
						LOG_DEBUG("Text", "Scrolling to saved origin");
						[clip scrollToPoint:_info.origin];
						[scrollerv reflectScrolledClipView:clip];
						
						if (!NSEqualRanges(_info.selection, NSZeroRange))
							[textv setSelectedRange:_info.selection];
					}
					else if (!NSEqualRanges(_info.selection, NSZeroRange) && _info.selection.location + _info.selection.length <= controller.text.length)
					{
						LOG_DEBUG("Text", "Scrolling to saved selection");
						[textv setSelectedRange:_info.selection];
						[textv scrollRangeToVisible:_visible];
						
						[textv showFindIndicatorForRange:_deferred];
					}
					else
					{
						LOG_DEBUG("Text", "Not scrolling to saved selection");
					}
				}
			}
			
			finished = true;
		}
	}
	
	return finished;
}

@end
