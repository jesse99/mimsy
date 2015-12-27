#import "FindController.h"

#import "AppDelegate.h"
#import "BaseTextController.h"

static FindController* _findController = nil;

@implementation FindController
{
	__weak BaseTextController* _controller;
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

typedef void (^FindBlock)(BaseTextController* controller, NSRegularExpression* regex, NSTextCheckingResult* match);

// The block is called on the main thread if the find succeeded.
- (void)_find:(FindBlock)block
{
	BaseTextController* controller = [BaseTextController frontmost];
	NSRegularExpression* regex = [self _getRegex];
	if (controller && !_finding && regex)
	{
		[self _cacheText:controller];
		NSRange selRange = [controller getTextView].selectedRange;
		NSUInteger searchFrom = selRange.location + selRange.length;
		__block NSRange searchRange = NSMakeRange(searchFrom, _text.length - searchFrom);
		NSString* findText = [self.findText copy];
		_finding = true;

        AppDelegate* app = [NSApp delegate];
        bool wrap = [app.layeredSettings boolValue:@"FindWraps" missing:true];
		
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
			   void (^matcher)(NSTextCheckingResult*, NSMatchingFlags, BOOL*) =
				   ^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
				   {
					   UNUSED(flags);
					   if (result && [self _rangeMatches:result.range controller:[BaseTextController frontmost]])
					   {
						   match = result;
						   range = result.range;
						   *stop = TRUE;
					   }
				   };
			   
			   ASSERT(searchRange.location <= _text.length);
			   ASSERT(searchRange.location + searchRange.length <= _text.length);
			   [regex enumerateMatchesInString:_text options:options range:searchRange usingBlock:matcher];
			   
			   if (range.location == NSNotFound && wrap)
			   {
				   if (searchFrom > 1)
				   {
					   searchRange = NSMakeRange(0, searchFrom - 1);

					   ASSERT(searchRange.location <= _text.length);
					   ASSERT(searchRange.location + searchRange.length <= _text.length);
					   [regex enumerateMatchesInString:_text options:options range:searchRange usingBlock:matcher];
				   }
				   wrappedAround = true;
			   }
			   
			   dispatch_async(main,
				  ^{
					  if (wrappedAround)
						  _wrappedAround = true;
					  
					  if (range.location != NSNotFound)
					  {
						  BaseTextController* controller = _controller;
						  if (controller)
						  {
							  if (_wrappedAround && range.location + range.length >= _initialSearchFrom)
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
		 ^(BaseTextController* controller, NSRegularExpression* regex, NSTextCheckingResult* match)
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
	
	BaseTextController* controller = [BaseTextController frontmost];
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
					   if (result && [self _rangeMatches:result.range controller:[BaseTextController frontmost]])
						   candidate = result.range;
				   }];
			   
			   dispatch_async(main,
				  ^{
					  if (candidate.location != NSNotFound)
					  {
						  BaseTextController* controller = _controller;
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

- (IBAction)replace:(id)sender
{
	UNUSED(sender);
		
	[self _updateComboBox:self.replaceWithComboBox with:self.replaceText];

	[self _find:
		 ^(BaseTextController* controller, NSRegularExpression* regex, NSTextCheckingResult* match)
		 {
			 NSString* template = [self _getReplaceTemplate];
			 [self _replace:controller regex:regex match:match with:template showSelection:true];
		 }];
}

- (IBAction)replaceAll:(id)sender
{
	UNUSED(sender);

	NSRegularExpression* regex = [self _getRegex];
	if (!_finding && regex)
	{
		[self _updateComboBox:self.findComboBox with:self.findText];
		[self _updateComboBox:self.replaceWithComboBox with:self.replaceText];

		NSString* template = [self _getReplaceTemplate];
		BaseTextController* textController = [BaseTextController frontmost];
		NSUInteger count = replaceAll(self, textController, regex, template);
		
		if (count > 0)
		{
			BaseTextController* controller = [BaseTextController frontmost];
			
			if (count == 1)
				[controller showInfo:@"Replaced 1 match"];
			else
				[controller showInfo:[NSString stringWithFormat:@"Replaced %ld matches", (unsigned long)count]];
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

- (void)_cacheText:(BaseTextController*)controller
{
	if (controller != _controller || controller.getEditCount != _editCount)
	{
		_controller = controller;
		_text = [controller.getTextView.textStorage.string copy];
		_editCount = controller.getEditCount;
	}
}

- (void)_enableButtons
{
	BaseTextController* controller = [BaseTextController frontmost];
	NSTextView* view = controller ? [controller getTextView] : nil;
	bool findable = controller && controller.getTextView.textStorage.string.length > 0 && self.findText.length > 0 && !_finding;
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
