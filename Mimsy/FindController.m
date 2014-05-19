#import "FindController.h"

#import "Assert.h"
#import "Logger.h"
#import "Settings.h"
#import "TextController.h"

static FindController* _findController = nil;

@implementation FindController
{
	__weak TextController* _controller;
	NSString* _text;
	NSUInteger _editCount;
	bool _finding;
	
	NSString* _initialFindText;
	NSUInteger _initialSearchFrom;
	bool _wrappedAround;
}

- (id)init
{
	self = [super initWithWindowNibName:@"FindWindow"];
    if (self)
	{
        // Initialization code here.
    }
    
    return self;
}

+ (FindController*)getController
{
	if (!_findController)
	{
		_findController = [FindController new];
		(void) _findController.window;				// this forces the controls to be initialized (so we can set the text within the find combo box before the window is ever displayed)
	}
	return _findController;
}

+ (void)show
{
	if (!_findController)
		_findController = [FindController new];
		
	[_findController showWindow:_findController.window];
	[_findController.window makeKeyAndOrderFront:self];
	[_findController.window makeFirstResponder:_findController.findComboBox];
	
	[_findController _enableButtons];
}

NSUInteger _initialSearchFrom;
bool _wrappedAround;

- (IBAction)find:(id)sender
{
	UNUSED(sender);
	
	TextController* controller = [TextController frontmost];
	NSRegularExpression* regex = [self _getRegex];
	if (controller && !_finding && regex)
	{
		[self _cacheText:controller];
		NSRange selRange = [controller getTextView].selectedRange;
		NSUInteger searchFrom = selRange.location + selRange.length;
		__block NSRange searchRange = NSMakeRange(searchFrom, _text.length - searchFrom);
		NSString* findText = [self.findText copy];
		_finding = true;
		bool wrap = [Settings boolValue:@"FindWraps" missing:true];
				
		if ([findText compare:_initialFindText] != NSOrderedSame)
		{
			_initialFindText = findText;
			_initialSearchFrom = searchFrom;
			_wrappedAround = false;
		}
		__block bool wrappedAround = false;
		
		dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_async(concurrent,
		   ^{
			   NSMatchingOptions options = NSMatchingWithTransparentBounds | NSMatchingWithoutAnchoringBounds;
			   
			   __block NSRange range = NSMakeRange(NSNotFound, 0);
			   [regex enumerateMatchesInString:_text options:options range:searchRange usingBlock:
					^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
					{
						UNUSED(flags);
						if (result && [self _rangeMatches:result.range])
						{
							range = result.range;
							*stop = true;
						}
					}];

			   if (range.location == NSNotFound && wrap)
			   {
				   searchRange = NSMakeRange(0, searchFrom - 1);
				   range = [regex rangeOfFirstMatchInString:_text options:options range:searchRange];
				   wrappedAround = true;
			   }
			   
			   dispatch_async(main,
			   ^{
				   if (wrappedAround)
					   _wrappedAround = true;
				   
				   if (range.location != NSNotFound)
				   {
					   TextController* controller = _controller;
					   if (controller)
					   {
						   if (_wrappedAround && range.location >= _initialSearchFrom)
						   {
							   [controller showInfo:@"Reached Start"];
							   _wrappedAround = false;
						   }
						   
						   [self _showSelection:range in:controller];
					   }
				   }
				   else
					   NSBeep();
				   _finding = false;
			   });
		   });
	}
}

// TODO: this doesn't respectFindWrap though I am not sure how that would work
// especially when mixing find next and find previous.
- (IBAction)findPrevious:(id)sender
{
	UNUSED(sender);
	
	TextController* controller = [TextController frontmost];
	NSRegularExpression* regex = [self _getRegex];
	if (controller && !_finding && regex)
	{
		[self _cacheText:controller];
		NSRange selRange = [controller getTextView].selectedRange;
		NSUInteger searchUntil = selRange.location;
		__block NSRange searchRange = NSMakeRange(0, searchUntil);
		_finding = true;
		
		dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_async(concurrent,
		   ^{
			   __block NSRange candidate = NSMakeRange(NSNotFound, 0);
			   
			   // There's no good way to search backwards so we'll use a bad way...
			   NSMatchingOptions options = NSMatchingWithTransparentBounds | NSMatchingWithoutAnchoringBounds;
			   [regex enumerateMatchesInString:_text options:options range:searchRange usingBlock:
					^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
				   {
					   UNUSED(flags, stop);
					   if (result && [self _rangeMatches:result.range])
						   candidate = result.range;
				   }];
			   
			   dispatch_async(main,
				  ^{
					  if (candidate.location != NSNotFound)
					  {
						  TextController* controller = _controller;
						  if (controller)
							  [self _showSelection:candidate in:controller];
					  }
					  else
						  NSBeep();
					  _finding = false;
				  });
		   });
	}
}

- (void)_showSelection:(NSRange)range in:(TextController*)controller
{
	[controller.window makeKeyAndOrderFront:self];
	[[controller getTextView] setSelectedRange:range];
	[[controller getTextView] scrollRangeToVisible:range];
	[[controller getTextView] showFindIndicatorForRange:range];
}

- (void)_cacheText:(TextController*)controller
{
	if (controller != _controller || controller.editCount != _editCount)
	{
		_controller = controller;
		_text = [controller.text copy];
		_editCount = controller.editCount;
	}
}

- (IBAction)replace:(id)sender
{
	UNUSED(sender);
	LOG_INFO("Mimsy", "replace");
}

- (IBAction)replaceAll:(id)sender
{
	UNUSED(sender);
}

- (IBAction)replaceAndFind:(id)sender
{
	UNUSED(sender);
}

- (void)_enableButtons
{
	TextController* controller = [TextController frontmost];
	NSTextView* view = controller ? [controller getTextView] : nil;
	bool findable = controller && controller.text.length > 0 && self.findText.length > 0 && !_finding;
	bool editable = view && view.isEditable;
	
	[self.findButton setEnabled:findable];
	[self.replaceAllButton setEnabled:findable && editable];
	[self.replaceButton setEnabled:findable && editable];
	[self.replaceAndFindButton setEnabled:findable && editable];
}

- (void)controlTextDidChange:(NSNotification *)obj;
{
	UNUSED(obj);
	[_findController _enableButtons];
}

@end
