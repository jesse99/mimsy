#import "TextView.h"

#import "Assert.h"
#import "Logger.h"
#import "TextController.h"
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

- (NSMenu*)menuForEvent:(NSEvent*)event
{
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
	
	[self _extendSelection:event];
	[self.window makeKeyAndOrderFront:self];
	
	if (self.selectedRange.length > 0)
	{
		if (self.selectedRange.length < 100)
		{
			//NSString* selectedText = [self.textStorage.string substringWithRange:self.selectedRange];
			[self _addDictContextItem:menu];	// 0.11
		}
		
		if (self.isEditable)
		{
			
		}
	}
	
	return menu;
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
