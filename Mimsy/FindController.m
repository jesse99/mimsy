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

- (NSArray*)getHelpContext
{
	return @[@"find"];
}

typedef void (^FindBlock)(TextController* controller, NSRegularExpression* regex, NSTextCheckingResult* match);

// The block is called on the main thread if the find succeeded.
- (void)_find:(FindBlock)block
{
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
		
		[self _updateComboBox:self.findComboBox with:findText];
		
		if ([findText compare:_initialFindText] != NSOrderedSame)
		{
			_initialFindText = findText;
			_initialSearchFrom = searchFrom;
			_wrappedAround = false;
		}
		__block bool wrappedAround = false;
		__block NSTextCheckingResult* match = nil;
		
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
							match = result;
							range = result.range;
							*stop = TRUE;
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
							  
							  block(controller, regex, match);
						  }
					  }
					  else
						  NSBeep();
					  _finding = false;
				  });
		   });
	}
}

- (IBAction)find:(id)sender
{
	UNUSED(sender);
	
	[self _find:
		 ^(TextController* controller, NSRegularExpression* regex, NSTextCheckingResult* match)
		 {
			 UNUSED(regex);
			 [self _showSelection:match.range in:controller];
		 }];
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

- (void)_replace:(TextController*)controller regex:(NSRegularExpression*)regex match:(NSTextCheckingResult*)match with:(NSString*)template showSelection:(bool)showSelection
{
	NSTextView* view = [controller getTextView];
	NSMutableString* text = view.textStorage.mutableString;
	NSString* newText = [regex replacementStringForResult:match inString:text offset:0 template:template];

	if ([view shouldChangeTextInRange:match.range replacementString:newText])
	{
		NSRange newRange = NSMakeRange(match.range.location, newText.length);
		[text replaceCharactersInRange:match.range withString:newText];
		[view.undoManager setActionName:@"Replace"];
		[view didChangeText];

		if (showSelection)
			[self _showSelection:newRange in:controller];
	}
}

- (IBAction)replace:(id)sender
{
	UNUSED(sender);
		
	[self _updateComboBox:self.replaceWithComboBox with:self.replaceText];

	[self _find:
		 ^(TextController* controller, NSRegularExpression* regex, NSTextCheckingResult* match)
		 {
			 NSString* template = [self _getReplaceTemplate];
			 [self _replace:controller regex:regex match:match with:template showSelection:true];
		 }];
}

// It'd be simpler to use replaceMatchesInString but I couldn't get undo to undo the changes.
- (IBAction)replaceAll:(id)sender
{
	UNUSED(sender);

	NSRegularExpression* regex = [self _getRegex];
	if (!_finding && regex)
	{
		TextController* controller = [TextController frontmost];
		NSTextView* view = [controller getTextView];

		NSMutableString* text = view.textStorage.mutableString;
		NSRange searchRange = NSMakeRange(0, text.length);

		[self _updateComboBox:self.findComboBox with:self.findText];
		[self _updateComboBox:self.replaceWithComboBox with:self.replaceText];
		NSMutableArray* matches = [NSMutableArray new];	// used to avoid changing the text as we enumerate over it
		
	   [regex enumerateMatchesInString:text options:0 range:searchRange usingBlock:
			^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop)
			{
				UNUSED(flags, stop);
				if (match && [self _rangeMatches:match.range])
					[matches addObject:match];
			}];
		
		if (matches.count > 0)
		{
			[view.undoManager beginUndoGrouping];

			NSString* template = [self _getReplaceTemplate];
			for (NSUInteger i = matches.count - 1; i < matches.count; --i)
				[self _replace:controller regex:regex match:matches[i] with:template showSelection:false];

			[view.undoManager endUndoGrouping];
			[view.undoManager setActionName:@"Replace All"];
			
			NSTextCheckingResult* match = matches[matches.count-1];
			[self _showSelection:match.range in:controller];

			if (matches.count == 1)
				[controller showInfo:@"Replaced 1 match"];
			else
				[controller showInfo:[NSString stringWithFormat:@"Replaced %ld matches", (unsigned long)matches.count]];
		}
		else
		{
			NSBeep();
		}
	}
}

- (IBAction)replaceAndFind:(id)sender
{
	[self replace:sender];
	[self find:sender];
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
