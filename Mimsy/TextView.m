#import "TextView.h"

#import "AppDelegate.h"
#import "AppSettings.h"
#import "Balance.h"
#import "Constants.h"
#import "Extensions.h"
#import "Language.h"
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

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedRange granularity:(NSSelectionGranularity)granularity
{
	NSRange result;
	
	TextController* controller = _controller;
	if (granularity == NSSelectByWord && controller && controller.language != nil)
	{
		result = proposedRange;
		
		while (result.location > 0 && [self _matchesWord:controller.language.word at:result.location - 1 len:result.length + 1])
		{
			--result.location;
			++result.length;
		}
		
		while ([self _matchesWord:controller.language.word at:result.location len:result.length + 1])
		{
			++result.length;
		}
	}
	else
	{
		result = [super selectionRangeForProposedRange:proposedRange granularity:granularity];
	}
	
	return result;
}

- (void)keyDown:(NSEvent*)event
{
	do
	{
		if ([self _invokeExtensions:event])
			break;
		
		if ([self _handleTabKey:event])
			break;

		[super keyDown:event];
		
		NSString* chars = event.characters;
		[self _handleCloseBrace:chars];
	}
	while (false);
}

- (bool)_invokeExtensions:(NSEvent*)event
{
	bool handled = false;
	
	if (event.keyCode == TabKeyCode)
	{
		NSString* path = @"/mimsy/keydown/text-editor/tab/pressed";
		handled = [Extensions invoke:path];
	}
	
	return handled;
}

- (bool)_handleTabKey:(NSEvent*)event
{
	if (event.keyCode == TabKeyCode)
	{
		TextController* controller = self.window.windowController;
		if ((event.modifierFlags & (NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask)) == 0)
		{
			if (self.selectedRange.length > 1)
			{
				// Tab with at least one line selected indents lines
				if ([self _rangeCrossesLines:self.selectedRange])
				{
					[controller shiftRight:self];
					return true;
				}
			}
			else if (self.selectedRange.length == 0)
			{
				// Tab with no selection at the end of a blank line indents like the previous line.
				if ([self _matchPriorLineTabs:self.selectedRange.location])
					return true;
			}

			// TODO: should have am option (or plugin) for this
//			if (controller.Language != null && !controller.UsesTabs)
//			{
//				if (!NSObject.IsNullOrNil(controller.SpacesText))
//				{
//					this.insertText(controller.SpacesText);
//					return true;
//				}
//			}
		}
		else if (((event.modifierFlags & (NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask)) == 0) && (event.modifierFlags & NSShiftKeyMask) == NSShiftKeyMask)
		{
			// Shift-tab with at least one line selected unindents lines
			if ([self _rangeCrossesLines:self.selectedRange])
			{
				[controller shiftLeft:self];
				return true;
			}
		}
	}
	
	return false;
}

- (bool)_rangeCrossesLines:(NSRange)range
{
	NSUInteger first = [self getLineStart:range.location];
	NSUInteger last = [self getLineStart:range.location + range.length];
	
	return first != last;
}

// Returns a new index >= 0 and <= text.length and <= than the original index.
// Returns the same index if the previous character is a newline.
- (NSUInteger)getLineStart:(NSUInteger)index
{
	NSString* text = self.textStorage.string;
	
	NSUInteger len = self.textStorage.string.length;
	if (len == 0) return 0;
	if (index > len) index = len - 1;
	if (index > 0 && [text characterAtIndex:index-1] == '\n') return index;
	while (index > 0 && [text characterAtIndex:index-1] != '\n') --index;
	return index;
}

// DoMatchPriorLineTabs:
//    If at eol and all preceding chars on current line are tabs (or empty),
//    then match the leading tabs of the above line and return true.
// Terms: eol = end of line, bof = beginning of file, etc.
// Test cases:
//    * At bol, prev line has >= 1 leading tabs. Press Tab.
//    * At bol, prev line has 0 leading tabs. Press Tab.
//    * At eol with one leading tab, prev line has >= 1 leading tabs. Press Tab.
//    * At eol with one leading tab, prev line has 0 leading tabs. Press Tab.
//    * Empty file. Press Tab.
//	  * At bof. Press Tab.
// To do:
//    * Doesn't handle when there are nothing but tabs after the current cursor location.
- (bool)_matchPriorLineTabs:(NSUInteger)location
{
	NSString* text = self.textStorage.string;

	if (location >= text.length) return false;  // out of range
	NSUInteger thisLineStart = [self getLineStart:location];
	if (thisLineStart == 0) return false;  // there is no previous line to match tab chars with
	if (location != text.length      // not at end of text
		&& location != text.length-1 // not at end of text
		&& [text characterAtIndex:location] != '\n')     // not at end of line
	{ return false; }
	// at this point, there is a previous line and the cursor is at the end of the current line
	// now exit if non-tab chars between the bol and location
	for (NSUInteger i = thisLineStart; i < location; i++)
		if ([text characterAtIndex:i] != '\t') return false;
	NSUInteger prevLineStart = [self getLineStart:thisLineStart - 2];
	NSUInteger prevTabCount = [self _getLeadingTabCount:prevLineStart];
	if (prevTabCount <= (location - thisLineStart)) return false;
	// add new tabs with undo
	NSString* newTabs = [NSString stringWithN:prevTabCount - (location - thisLineStart) instancesOf:@"\t"];
	NSArray* args = @[[NSValue valueWithRange:NSMakeRange(location, 0)], newTabs, @""];
	[self _replaceSelection:args];
	[self setSelectedRange:NSMakeRange(location + newTabs.length, 0)];
	return true;
}

- (NSUInteger)_getLeadingTabCount:(NSUInteger)i
{
	NSString* text = self.textStorage.string;
	ASSERT(i == 0 || [text characterAtIndex:i-1] == '\n');
	
	NSUInteger j = i;
	while (j < text.length && [text characterAtIndex:j] == '\t') j++;
	return j - i;
}

// args[0] == text range
// args[1] == text which will replace the range
// args[2] == undo text
- (void)_replaceSelection:(NSArray*)args
{
	NSValue* value = args[0];
	NSRange oldRange = value.rangeValue;
	
	NSString* text = self.textStorage.string;
	NSString* oldText = [text substringWithRange:oldRange];	// TODO: if we can figure out that the selection is a class or method then we should add that to our url
	NSString* newText = args[1];
	[self replaceCharactersInRange:oldRange withString:newText];
	
	NSRange newRange = NSMakeRange(oldRange.location, newText.length);
	
	NSArray* oldArgs = @[[NSValue valueWithRange:newRange], oldText, args[2]];
	TextController* controller = self.window.windowController;
	NSDocument* doc = controller.document;
	[doc.undoManager registerUndoWithTarget:self selector:@selector(_replaceSelection:) object:oldArgs];
	[doc.undoManager setActionName:args[2]];
}

- (void)_handleCloseBrace:(NSString*)chars
{
	TextController* controller = self.window.windowController;
	if (chars.length == 1 && [controller isBrace:[chars characterAtIndex:0]])
	{
		NSRange range = self.selectedRange;
		if (range.length == 0)
		{
			// If the user typed a closing brace and it is balanced,
			bool indexIsOpenBrace, indexIsCloseBrace, foundOtherBrace;
			NSString* text = self.textStorage.string;
			NSUInteger left = tryBalance(text, range.location + range.length - 1, &indexIsOpenBrace, &indexIsCloseBrace, &foundOtherBrace, ^(NSUInteger index){return [controller isOpenBrace:index];}, ^(NSUInteger index){return [controller isCloseBrace:index];});
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
					unichar ch = [text characterAtIndex:range.location-1];
					[controller showWarning:[NSString stringWithFormat:@"Unmatched %C", ch]];
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
		TextController* controller = self.window.windowController;
		NSRange selRange = tryBalanceRange(self.textStorage.string, self.selectedRange, ^(NSUInteger index){return [controller isOpenBrace:index];}, ^(NSUInteger index){return [controller isCloseBrace:index];});
		
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
	NSRange oldSelection = self.selectedRange;
	[super paste:sender];
	
	TextController* controller = _controller;
	if (controller)
		[controller resetAttributes];
	
	if (![AppSettings boolValue:@"PasteCopiesBackColor" missing:false])
	{
		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		NSString* str = [pb stringForType:NSStringPboardType];
		NSString* currentText = self.textStorage.string;
		
		// If it is a windows endian file the text will be fixed up when it is saved.
		// If not then we don't want to mix line endings.
		str = [str replaceCharacters:@"\r\n" with:@"\n"];

		// Not sure why but it seems that str.length is sometimes longer than
		// what is pasted.
		NSUInteger len;
		if (oldSelection.location + str.length <= currentText.length)
			len = str.length;
		else
			len = currentText.length - oldSelection.location;
		
		[self.textStorage removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange(oldSelection.location, len)];
	}
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

- (bool)_matchesWord:(NSRegularExpression*)word at:(NSUInteger)loc len:(NSUInteger)len
{
	bool matches = false;
	
	if (loc + len <= self.textStorage.string.length)
	{
		NSTextCheckingResult* match = [word firstMatchInString:self.textStorage.string options:NSMatchingWithTransparentBounds range:NSMakeRange(loc, len)];
		matches = match != nil && match.range.length == len;
	}
	
	return matches;
}

@end
