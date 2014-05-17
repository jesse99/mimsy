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
	if (controller && !_finding)
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
			   NSRange range = [_text rangeOfString:findText options:NSCaseInsensitiveSearch range:searchRange];
			   if (range.location == NSNotFound && wrap)
			   {
				   searchRange = NSMakeRange(0, searchFrom - 1);
				   range = [_text rangeOfString:findText options:NSCaseInsensitiveSearch range:searchRange];
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
