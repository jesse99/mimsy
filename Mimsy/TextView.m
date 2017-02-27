#import "TextView.h"

#import "AppDelegate.h"
#import "Balance.h"
#import "Constants.h"
#import "GlyphGenerator.h"
#import "Language.h"
#import "MenuCategory.h"
#import "SearchSite.h"
#import "TextController.h"
#import "TimeMachine.h"
#import "Utils.h"

@implementation TextView
{
    __weak TextController* _controller;
    bool _changingBackColor;
    bool _restored;
    bool _doubleClicking;
    NSRange _lastDoubleRange;
}

- (void)onOpened:(TextController*)controller
{
    _controller = controller;
    
    GlyphGenerator *generator = [GlyphGenerator new];
    [self.layoutManager setGlyphGenerator:generator];
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
    NSRange result = NSMakeRange(NSNotFound, 0);

    TextController* controller = _controller;
    if (_doubleClicking && granularity == NSSelectByWord && controller && controller.language != nil)
    {
        if (_lastDoubleRange.length == 0 || proposedRange.length == 0)
        {
            // initial double click
            NSRange proposed = NSMakeRange(proposedRange.location, 1);
            result = [self _extendRe:controller.language.word proposedRange:proposed lookAround:16];
            
            if (result.length == 0)
            {
                result = [self _extendRe:controller.language.number proposedRange:proposed lookAround:16];
                
                // special case where the user double-clicks a number embedded in a word
                if (result.length > 0)
                    result = [self _extendRe:controller.language.word proposedRange:result lookAround:16];
            }
        }
        else
        {
            // double click drag
            if (proposedRange.location != _lastDoubleRange.location)
            {
                NSRange range = [self _findWordToLeft:proposedRange];
                if (range.location != NSNotFound && range.location + range.length == proposedRange.location)
                {
                    NSUInteger left = range.location;
                    result = NSMakeRange(left, proposedRange.location - left + proposedRange.length);
                }
                else
                    result = proposedRange;
            }
            else if (proposedRange.length != _lastDoubleRange.length)
            {
                NSRange range = [self _findWordToRight:proposedRange];
                if (range.location != NSNotFound && range.location == proposedRange.location + proposedRange.length)
                {
                    NSUInteger right = range.location + range.length;
                    result = NSMakeRange(proposedRange.location, right - proposedRange.location);
                }
                else
                    result = proposedRange;
            }
            else
                result = _lastDoubleRange;
        }
        
        if (result.length != 0)
            _lastDoubleRange = result;
    }
    
    if (result.length == 0)
        result = [super selectionRangeForProposedRange:proposedRange granularity:granularity];
    
    return result;
}

// It'd be nice to simply use selectionRangeForProposedRange for these but that doesn't give us directionality
// which makes it very awkward.
- (void)moveWordLeft:(id)sender
{
    NSUInteger offset = [self _findWordToLeft:self.selectedRange].location;
    if (offset != NSNotFound)
        [self setSelectedRange:NSMakeRange(offset, 0)];
    else
        [super moveWordLeft:sender];
}

- (void)moveWordRight:(id)sender
{
    NSRange range =[self _findWordToRight:self.selectedRange];
    NSUInteger offset = range.location + range.length;
    if (offset != NSNotFound)
        [self setSelectedRange:NSMakeRange(offset, 0)];
    else
        [super moveWordRight:sender];
}

- (void)moveWordLeftAndModifySelection:(id)sender
{
    NSRange oldRange = [self selectedRange];
    NSUInteger offset = [self _findWordToLeft:oldRange].location;
    if (offset != NSNotFound)
        [self setSelectedRange:NSMakeRange(offset, oldRange.location + oldRange.length - offset)];
    else
        [super moveWordLeftAndModifySelection:sender];
}

- (void)moveWordRightAndModifySelection:(id)sender
{
    NSRange oldRange = [self selectedRange];
    NSRange range =[self _findWordToRight:oldRange];
    NSUInteger offset = range.location + range.length;
    if (offset != NSNotFound)
        [self setSelectedRange:NSMakeRange(oldRange.location, offset - oldRange.location)];
    else
        [super moveWordRightAndModifySelection:sender];
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

static NSString* decorateKey(NSEvent* event, NSString* key)
{
    NSMutableArray* labels = [NSMutableArray new];
    
    if (event.modifierFlags & NSCommandKeyMask)
        [labels addObject:@"command"];
    
    if (event.modifierFlags & NSControlKeyMask)
        [labels addObject:@"control"];
    
    if (event.modifierFlags & NSAlternateKeyMask)
        [labels addObject:@"option"];
    
    if (event.modifierFlags & NSShiftKeyMask)
        [labels addObject:@"shift"];
    
    [labels addObject:key];
    
    return [labels componentsJoinedByString:@"-"];
}

static NSString* getKey(NSEvent* event)
{
    switch (event.keyCode)
    {
        case ANSI_KeypadClearKeyCode:
            return @"clear";
            
        case DeleteKeyCode:
            return @"delete";
            
        case DownArrowKeyCode:
            return @"down-arrow";
            
        case EndKeyCode:
            return @"end";
            
        case ANSI_KeypadEnterKeyCode:
            return @"enter";
            
        case EscapeKeyCode:
            return @"escape";
            
        case ForwardDeleteKeyCode:
            return @"forward-delete";
            
        case HelpKeyCode:
            return @"help";
            
        case HomeKeyCode:
            return @"home";
            
        case LeftArrowKeyCode:
            return @"left-arrow";
            
        case PageUpKeyCode:
            return @"page-up";
            
        case RightArrowKeyCode:
            return @"right-arrow";
            
        case TabKeyCode:
            return @"tab";
            
        case UpArrowKeyCode:
            return @"up-arrow";
            
            
        case F1KeyCode:
            return @"f1";
            
        case F2KeyCode:
            return @"f2";
            
        case F3KeyCode:
            return @"f3";
            
        case F4KeyCode:
            return @"f4";
            
        case F5KeyCode:
            return @"f5";
            
        case F6KeyCode:
            return @"f6";
            
        case F7KeyCode:
            return @"f7";
            
        case F8KeyCode:
            return @"f8";
            
        case F9KeyCode:
            return @"f9";
            
            
        case F10KeyCode:
            return @"f10";
            
        case F11KeyCode:
            return @"f11";
            
        case F12KeyCode:
            return @"f12";
            
        case F13KeyCode:
            return @"f13";
            
        case F14KeyCode:
            return @"f14";
            
        case F15KeyCode:
            return @"f15";
            
        case F16KeyCode:
            return @"f16";
            
        case F17KeyCode:
            return @"f17";
            
        case F18KeyCode:
            return @"f18";
            
        case F19KeyCode:
            return @"f19";
    }
    
    return nil;
}

- (bool)_invokeExtensions:(NSEvent*)event
{
    bool handled = false;
    
    NSString* key = getKey(event);
    if (key)
    {
        NSString* fn = decorateKey(event, key);
        
        AppDelegate* app = (AppDelegate*) [NSApp delegate];
        TextController* controller = self.window.windowController;
        handled = [app invokeTextViewKeyHook:fn view:controller];
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
    _lastDoubleRange = NSMakeRange(NSNotFound, 0);
    _doubleClicking = event.clickCount == 2;
    [super mouseDown:event];
    _doubleClicking = false;
    _lastDoubleRange = NSMakeRange(NSNotFound, 0);
    
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
        {
            [self setSelectedRange:selRange];
            return;
        }
    }
}

- (NSMenu*)menuForEvent:(NSEvent*)event
{
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
    
    _doubleClicking = true;             // not actually a double click but we want to do the same sort of thing...
    [self _extendSelection:event];
    _doubleClicking = false;
    [self.window makeKeyAndOrderFront:self];
    
    NSArray<TextContextMenuBlock>* items;
    if (self.selectedRange.length > 0)
    {
        if (self.selectedRange.length < 100)
            [self _addDictContextItem:menu];			// 0.11
        if (self.selectedRange.length < 1000)
            [self _addSiteSearchContextItem:menu];		// 0.11
        
        items = [app withSelectionItems:WithTextSelectionPosLookup];
        [self _addItems:menu items:items];
        
        items = [app withSelectionItems:WithTextSelectionPosTransform];
        [self _addItems:menu items:items];

        items = [app withSelectionItems:WithTextSelectionPosSearch];
        [self _addItems:menu items:items];
        
        if (self.isEditable)    // TODO: get rid of isEditable checks?
        {
            if ([self _needsSpellCheck])
                [self _addSpellCheckContextItem:menu];	// 0.9
        }

        items = [app withSelectionItems:WithTextSelectionPosAdd];
        [self _addItems:menu items:items];
    }
    else
    {
        items = [app noSelectionItems:NoTextSelectionPosStart];
        [self _addItems:menu items:items];
        [self _addWordWrapContextMenu:menu];			// 0.853
        
        items = [app noSelectionItems:NoTextSelectionPosMiddle];
        [self _addItems:menu items:items];
        
        items = [app noSelectionItems:NoTextSelectionPosEnd];
        [self _addItems:menu items:items];
        [self _addTimeMachineContextMenu:menu];			// 0.9
    }
    
    return menu;
}

- (void)_addItems:(NSMenu*)menu items:(NSArray<TextContextMenuBlock>*)blocks
{
    TextController* controller = _controller;
    if (controller)
    {
        bool addedSep = false;
        for (TextContextMenuBlock block in blocks)
        {
            NSArray<TextContextMenuItem*>* items = block(controller);
            for (TextContextMenuItem* item in items)
            {
                if (!addedSep)
                {
                    if (menu.numberOfItems > 0)
                        [menu addItem:[NSMenuItem separatorItem]];
                    addedSep = true;
                }

                NSMenuItem* mitem = [[NSMenuItem alloc] initWithTitle:item.title action:@selector(_processTextContextItem:) keyEquivalent:@""];
                [mitem setRepresentedObject:item.invoke];
                [menu appendSortedItem:mitem];
            }
        }
    }
}

- (void)_processTextContextItem:(NSMenuItem*)sender
{
    TextController* controller = _controller;
    if (controller)
    {
        InvokeTextCommandBlock invoke = sender.representedObject;
        invoke(controller);
    }
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

- (void)_processCopyPathItem:(id)sender
{
    UNUSED(sender);
    
    TextController* controller = _controller;
    if (controller)
    {
        NSPasteboard* pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb writeObjects:@[controller.path.asString]];
    }
}

- (void) _addTimeMachineContextMenu:(NSMenu*)menu
{
    [TimeMachine appendContextMenu:menu];
}

- (void)_addSiteSearchContextItem:(NSMenu*)menu
{
    TextController* controller = _controller;
    if (controller)
        [SearchSite appendContextMenu:menu context:controller];
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
        [controller resetTypingAttributes];
    
    if (![controller.layeredSettings boolValue:@"PasteCopiesBackColor" missing:false])
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

- (NSRange)_extendLeft:(NSRegularExpression*)re proposedRange:(NSRange)proposedRange lookAround:(NSUInteger)lookAround
{
    NSRange result = NSMakeRange(NSNotFound, 0);
    
    //LOG("App", "text = %s", STR([self.textStorage.string substringWithRange:proposedRange]));
    //LOG("App", "re = %s", STR(re));
    
    if ([self _matchesWord:re at:proposedRange.location len:proposedRange.length])
    {
        result = proposedRange;
        
        // If we have a word on the left side then try to extend it leftward. Note that we have to
        // be careful about how we do this so that double click dragging works. Also for numbers
        // we need to allow jumping by more than one character (otherwise stuff the "3.14e-" in
        // "3.14e-2" won't match.
        while (true)
        {
            NSUInteger count = 0;
            for (NSUInteger i = 1; result.location >= i && i <= lookAround && count == 0; ++i)
            {
                if ([self _matchesWord:re at:result.location - i len:result.length + i])
                    count = i;
            }
            
            if (count > 0)
            {
                result.location -= count;
                result.length += count;
            }
            else
                break;
            
            //LOG("App", "   text1 = %s", STR([self.textStorage.string substringWithRange:result]));
        }
    }
    
    return result;
}

- (NSRange)_extendRight:(NSRegularExpression*)re proposedRange:(NSRange)proposedRange lookAround:(NSUInteger)lookAround
{
    NSRange result = NSMakeRange(NSNotFound, 0);
    
    //LOG("App", "text = %s", STR([self.textStorage.string substringWithRange:proposedRange]));
    //LOG("App", "re = %s", STR(re));
    
    if ([self _matchesWord:re at:proposedRange.location len:proposedRange.length])
    {
        result = proposedRange;
        
        // If we have a word on the right side then try to extend it rightward.
        while (true)
        {
            NSUInteger count = 0;
            for (NSUInteger i = 1; i <= lookAround && count == 0; ++i)
            {
                if ([self _matchesWord:re at:result.location len:result.length + i])
                    count = i;
            }
            
            if (count > 0)
                result.length += count;
            else
                break;
            
            //LOG("App", "   text2 = %s", STR([self.textStorage.string substringWithRange:result]));
        }
    }
    
    return result;
}

- (NSRange)_extendRe:(NSRegularExpression*)re proposedRange:(NSRange)proposedRange lookAround:(NSUInteger)lookAround
{
    NSRange result = [self _extendLeft:re proposedRange:proposedRange lookAround:lookAround];
    
    if (result.location != NSNotFound)
        result = [self _extendRight:re proposedRange:result lookAround:lookAround];
    else
        result = [self _extendRight:re proposedRange:proposedRange lookAround:lookAround];
    
    return result;
}

- (bool)_matchesWord:(NSRegularExpression*)word at:(NSUInteger)loc len:(NSUInteger)len
{
    bool matches = false;
    
    if (loc + len <= self.textStorage.string.length)
    {
        NSTextCheckingResult* match = [word firstMatchInString:self.textStorage.string options:NSMatchingWithTransparentBounds range:NSMakeRange(loc, len)];
        matches = match != nil && match.range.length == len;
    }
    //LOG("App", "      match '%s' = %s", STR([self.textStorage.string substringWithRange:NSMakeRange(loc, len)]), matches ? "true" : "false");
    
    return matches;
}

- (NSRange)_findWordToLeft:(NSRange)using
{
    TextController* controller = _controller;
    if (controller && controller.language != nil)
    {
        NSUInteger offset = using.location;
        while (offset > 0)
        {
            --offset;
            NSRange range = [self _extendLeft:controller.language.word proposedRange:NSMakeRange(offset, 1) lookAround:16];
            
            // Yuckily enough we also need to special case numbers because Cocoa selects too little of "10.11e+100"
            // and too much of "10,20,30". Note that we need a lookAround large enough to handle the maximum
            // number of fractional digits ("11e+100" isn't always a legal number).
            if (range.length == 0)
                range = [self _extendLeft:controller.language.number proposedRange:NSMakeRange(offset, 1) lookAround:16];
            
            if (range.length > 0)
                return range;
        }
    }
    
    return NSMakeRange(NSNotFound, 0);
}

- (NSRange)_findWordToRight:(NSRange)using
{
    TextController* controller = _controller;
    if (controller && controller.language != nil)
    {
        NSUInteger offset = using.location + using.length;
        while (offset < self.textStorage.string.length)
        {
            NSRange range = [self _extendRight:controller.language.word proposedRange:NSMakeRange(offset, 1) lookAround:16];
            if (range.length == 0)
                range = [self _extendRight:controller.language.number proposedRange:NSMakeRange(offset, 1) lookAround:16];
            
            if (range.length > 0)
                return range;
            
            ++offset;
        }
    }
    
    return NSMakeRange(NSNotFound, 0);
}

@end
