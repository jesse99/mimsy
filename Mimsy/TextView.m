#import "TextView.h"

#import "AppDelegate.h"
#import "Assert.h"
#import "Balance.h"
#import "Constants.h"
#import "Logger.h"
#import "SearchSite.h"
#import "TextController.h"
#import "TimeMachine.h"
#import "Utils.h"

@implementation TextView
{
	__weak TextController* _controller;
	bool _changingBackColor;
	bool _restored;
}

- (void)onOpened:(TextController*)controller
{
	_controller = controller;
}

- (void)restoreStateWithCoder:(NSCoder*)coder
{
	[super restoreStateWithCoder:coder];
	_restored = true;
}

- (bool)restored
{
	return _restored;
}

- (void)keyDown:(NSEvent*)event
{
	[super keyDown:event];
	
	NSString* chars = event.characters;
	[self _handleCloseBrace:chars];
}

- (void)_handleCloseBrace:(NSString*)chars
{
	if (chars.length == 1 && isBrace([chars characterAtIndex:0]))
	{
		NSRange range = self.selectedRange;
		if (range.length == 0)
		{
			TextController* controller = self.window.windowController;

			// If the user typed a closing brace and it is balanced,
			bool indexIsOpenBrace, indexIsCloseBrace, foundOtherBrace;
			NSString* text = self.textStorage.string;
			NSUInteger left = tryBalance(text, range.location + range.length - 1, &indexIsOpenBrace, &indexIsCloseBrace, &foundOtherBrace);
			if (indexIsCloseBrace)
			{
				// then highlight the open brace.
				if (foundOtherBrace)
				{
					NSRange openRange = NSMakeRange(left, 1);
					[self _showOpenBrace:openRange closedAt:range];
				}
				else if (range.location < text.length)
				{
					// Otherwise pop up a translucent warning window for a second.
					unichar ch = [text characterAtIndex:range.location];
					[controller showWarning:[NSString stringWithFormat:@"Unmatched '%C'", ch]];
				}
			}
		}
	}
}

- (void)_showOpenBrace:(NSRange)openRange closedAt:(NSRange)closeRange
{
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
	dispatch_after(delay, main, ^
   {
	   [self scrollRangeToVisible:openRange];
	   [self showFindIndicatorForRange:openRange];
	   
	   dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 333*NSEC_PER_MSEC);
	   dispatch_after(delay, main, ^
	  {
		  [self scrollRangeToVisible:closeRange];
	  });
   });
}

- (void)mouseDown:(NSEvent*)event
{
	[super mouseDown:event];
	
	if (event.clickCount == 2 && self.selectedRange.length == 1)
	{
		// This works a bit differently then the Balance menu command in that it
		// selects the braces. But it would be odd if double-clicking a brace
		// didn't select that brace. And maybe it's a good idea to have two
		// methods that do the same thing differently given how people's
		// preferences differ.
		NSRange selRange = tryBalanceRange(self.textStorage.string, self.selectedRange);
		
		if (selRange.length > 0)
			[self setSelectedRange:selRange];
	}
}

- (NSMenu*)menuForEvent:(NSEvent*)event
{
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
	
	[self _extendSelection:event];
	[self.window makeKeyAndOrderFront:self];
	
	if (self.selectedRange.length > 0)
	{
		if (self.selectedRange.length < 100)
			[self _addDictContextItem:menu];			// 0.11
		
		if (self.selectedRange.length < 1000)
			[self _addSiteSearchContextItem:menu];		// 0.11
		
		if (self.isEditable)
		{
			[self _addTransformsContextMenu:menu];		// 0.8
		}

		if (self.isEditable)
		{
			if ([self _needsSpellCheck])
				[self _addSpellCheckContextItem:menu];	// 0.9
		}
	}
	else
	{
		[self _addWordWrapContextMenu:menu];			// 0.853
		[self _addCopyPathContextMenu:menu];			// 0.891
		
		[menu addItem:[NSMenuItem separatorItem]];
		[self _addTimeMachineContextMenu:menu];			// 0.9
	}
	
	return menu;
}

- (bool)_needsSpellCheck
{
	// If the selection is large or has multiple words then don't spell check it.
	if (self.selectedRange.length > 100)
		return false;
	
	NSRange range = [self selectedRange];
	NSCharacterSet* cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	for (NSUInteger offset = 0; offset < self.selectedRange.length; ++offset)
	{
		unichar ch = [self.textStorage.string characterAtIndex:range.location+offset];
		if ([cs characterIsMember:ch])
			return false;
	}
	
	// If the selection is one word and has an interior upper case letter
	// or underscore then don't spell check it.
	cs = [NSCharacterSet uppercaseLetterCharacterSet];
	for (NSUInteger offset = 1; offset < self.selectedRange.length; ++offset)
	{
		unichar ch = [self.textStorage.string characterAtIndex:range.location+offset];
		if (ch == '_' || [cs characterIsMember:ch])
			return false;
	}
	
	// Otherwise spell check it.
	return true;
}

- (void)_addSpellCheckContextItem:(NSMenu*)menu
{
	NSArray* guesses = [[NSSpellChecker sharedSpellChecker] guessesForWordRange:self.selectedRange inString:self.textStorage.string language:@"en_US" inSpellDocumentWithTag:0];	// TODO: how can we not hard-code the language?
	if (guesses.count > 0)
	{
		[menu addItem:[NSMenuItem separatorItem]];
		
		for (NSUInteger i = 0; i < guesses.count; ++i)
		{
			NSString* guess = [guesses[i] description];
			
			NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:guess action:@selector(_processRepObjectContextItem:) keyEquivalent:@""];
			[item setRepresentedObject:guess];
			[menu addItem:item];
		}
	}
}

- (void)_processRepObjectContextItem:(id)sender
{
	UNUSED(sender);
	
	[self.textStorage replaceCharactersInRange:self.selectedRange withString:[sender representedObject]];
}

- (void)_addTransformsContextMenu:(NSMenu*)menu
{
	[AppDelegate appendContextMenu:menu];
}

- (void)_addWordWrapContextMenu:(NSMenu*)menu
{
	TextController* controller = _controller;
	if (controller)
	{
		NSString* title = controller.isWordWrapping ? @"Don't Wrap Lines" : @"Wrap Lines";
		
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(_processWordWrapItem:) keyEquivalent:@""];
		[menu addItem:item];
	}
}

- (void)_processWordWrapItem:(id)sender
{
	UNUSED(sender);
	
	TextController* controller = _controller;
	if (controller)
		[controller toggleWordWrap];
}

- (void)_addCopyPathContextMenu:(NSMenu*)menu
{
	TextController* controller = _controller;
	if (controller)
	{
		NSString* title = @"Copy Path";
		
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(_processCopyPathItem:) keyEquivalent:@""];
		[menu addItem:item];
	}
}

- (void)_processCopyPathItem:(id)sender
{
	UNUSED(sender);
	
	TextController* controller = _controller;
	if (controller)
	{
		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		[pb writeObjects:@[controller.path]];
	}
}

- (void) _addTimeMachineContextMenu:(NSMenu*)menu
{
	[TimeMachine appendContextMenu:menu];
}

- (void)_addSiteSearchContextItem:(NSMenu*)menu
{
	[SearchSite appendContextMenu:menu];
}

- (void)_addDictContextItem:(NSMenu*)menu
{
	NSRange range = [self selectedRange];
	if (![[NSCharacterSet letterCharacterSet] characterIsMember:[self.textStorage.string characterAtIndex:range.location]])
		return;

	// Note that Dictionary.app will fall back to wikipedia for phrases so we
	// want to allow spaces.
	for (NSUInteger offset = 0; offset < range.length; ++offset)
	{
		unichar ch = [self.textStorage.string characterAtIndex:range.location+offset];
		if (ch == '\t' || ch == '\r' || ch == '\n')
			return;
	}
	
	NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"Look Up in Dictionary" action:@selector(_processDictContextItem:) keyEquivalent:@""];
	[menu addItem:item];
}

- (void)_processDictContextItem:(id)sender
{
	UNUSED(sender);
	
	NSString* selectedText = [self.textStorage.string substringWithRange:self.selectedRange];
	NSString* text = [selectedText stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
	NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"dict:///%@", text]];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)_extendSelection:(NSEvent*)event
{
	NSUInteger index = [self mouseEventToIndex:event];
	
	NSTextStorage* storage = [self textStorage];
	
	NSRange range = self.selectedRange;
	if (range.length == 0 && index < storage.length && [storage.string characterAtIndex:index] == '\n')
	{
		// don't extend the selection if the user clicked off to the right side of a line
	}
	else if (index >= storage.length)
	{
		// don't extend the selection if the user clicked below the last line of text
		[self setSelectedRange:NSZeroRange];
	}
	else
	{
		// Extend the selection so that it contains the entire word the user right-clicked on.
		if (range.length == 0 || !rangeIntersectsIndex(range, index))
		{
			range = NSMakeRange(index, 1);
			range = [self selectionRangeForProposedRange:range granularity:NSSelectByWord];
			[self setSelectedRange:range];
		}
	}
}

- (NSUInteger)mouseEventToIndex:(NSEvent*)event
{
//	NSPoint baseLoc = event.locationInWindow;
//	NSPoint viewLoc = [self convertPointFromBacking:baseLoc];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	return [self characterIndexForInsertionAtPoint:point];
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
	BOOL valid = NO;
	
	if (item.action == @selector(changeBackColor:))
	{
		// If the document has a language then the back color is set by a styles file.
		TextController* controller = _controller;
		if (controller)
			valid = controller.language == nil;
	}
	else if ([self respondsToSelector:item.action])
	{
		valid = YES;
	}
	else if ([super respondsToSelector:@selector(validateUserInterfaceItem:)])
	{
		valid = [super validateUserInterfaceItem:item];
	}
	
	return valid;
}

- (void)paste:(id)sender
{
	[super paste:sender];
	
	TextController* controller = _controller;
	if (controller)
		[controller resetAttributes];
}

- (void)orderFrontColorPanel:(id)sender
{
	NSColorPanel* panel = [NSColorPanel sharedColorPanel];
	[panel setContinuous:YES];
	[panel setColor:[NSColor whiteColor]];
	_changingBackColor = false;
	[NSApp orderFrontColorPanel:sender];
}

- (void)changeBackColor:(id)sender
{
	(void) sender;
	
	NSColorPanel* panel = [NSColorPanel sharedColorPanel];
	[panel setContinuous:YES];
	[panel setColor:self.backgroundColor];
	_changingBackColor = true;
	[panel makeKeyAndOrderFront:self];
}

// NSColorPanel is rather awful:
// 1) This method is always called on the first responder call setAction.
// 2) When the panel is closed the view (and every other document window!) is called
// with the original color.
- (void)changeColor:(id)sender
{
	if ([sender isVisible])
	{
		if (_changingBackColor)
		{
			TextController* controller = _controller;
			if (controller)
			{
				NSColor* color = [sender color];
				[self setBackgroundColor:color];
				[controller.document updateChangeCount:NSChangeDone | NSChangeDiscardable];
			}
		}
		else
		{
			[super changeColor:sender];
		}
	}
}

@end
