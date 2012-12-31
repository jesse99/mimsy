#import "RestoreView.h"

#import "Logger.h"
#import "TextController.h"
#import "TextView.h"
#import "Utils.h"
#import "WindowsDatabase.h"

@implementation RestoreView
{
	TextController* _controller;
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
				[_controller toggleWordWrap];
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
		if (_info.length == -1 || _info.length == _controller.text.length)	// only restore the view if it has not changed since we last had it open
		{
			LOG_DEBUG("Text", "Scrolling to saved location");
			if (!NSEqualPoints(_info.origin, NSZeroPoint))
			{
				NSClipView* clip = _controller.scrollView.contentView;
				[clip scrollToPoint:_info.origin];
				[_controller.scrollView reflectScrolledClipView:clip];
				
				if (!NSEqualRanges(_info.selection, NSZeroRange))
					[_controller.textView setSelectedRange:_info.selection];
			}
			else if (!NSEqualRanges(_info.selection, NSZeroRange) && _info.selection.location + _info.selection.length <= _controller.text.length)
			{
				[_controller.textView setSelectedRange:_info.selection];
				[_controller.textView scrollRangeToVisible:_visible];
				
				[_controller.textView showFindIndicatorForRange:_deferred];
			}
		}
		
		finished = true;
	}
	
	return finished;
}

@end
