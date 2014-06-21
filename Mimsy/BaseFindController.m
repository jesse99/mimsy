#import "BaseFindController.h"

#import "ArrayCategory.h"
#import "Assert.h"
#import "Constants.h"
#import "Language.h"
#import "Languages.h"
#import "Logger.h"
#import "RegexStyler.h"
#import "AppSettings.h"
#import "StringCategory.h"
#import "StyleRuns.h"
#import "TextController.h"
#import "TranscriptController.h"

// It'd be simpler to use replaceMatchesInString but I couldn't get undo to undo the changes.
NSUInteger replaceAll(BaseFindController* findController, BaseTextController* textController, NSRegularExpression* regex, NSString* template)
{
	NSTextView* view = [textController getTextView];
	
	NSMutableString* text = view.textStorage.mutableString;
	NSRange searchRange = NSMakeRange(0, text.length);
	NSMutableArray* matches = [NSMutableArray new];	// used to avoid changing the text as we enumerate over it
	
	[regex enumerateMatchesInString:text options:0 range:searchRange usingBlock:
	 ^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop)
	 {
		 UNUSED(flags, stop);
		 if (match && [findController _rangeMatches:match.range controller:textController])
			 [matches addObject:match];
	 }];
	
	if (matches.count > 0)
	{
		[view.undoManager beginUndoGrouping];
		[view.textStorage beginEditing];
		
		for (NSUInteger i = matches.count - 1; i < matches.count; --i)
			[findController _replace:textController regex:regex match:matches[i] with:template showSelection:false];
		
		[view.textStorage endEditing];
		[view.undoManager endUndoGrouping];
		[view.undoManager setActionName:@"Replace All"];
		
		NSTextCheckingResult* match = matches[matches.count-1];
		[findController _showSelection:match.range in:textController];
	}
	
	return matches.count;
}

@implementation BaseFindController
{
	NSString* _cachedPattern;
	NSRegularExpression* _cachedRegex;
	NSRegularExpression* _asciiRegex;
	NSRegularExpression* _uniRegex;
}

- (id)initWithWindowNibName:(NSString*)name
{
	self = [super initWithWindowNibName:name];
    if (self)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_settingsChanged:) name:@"AppSettingsChanged" object:nil];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[self.window setExcludedFromWindowsMenu:TRUE];
	[self _settingsChanged:nil];

	[_findComboBox setNumberOfVisibleItems:8];
	[_replaceWithComboBox setNumberOfVisibleItems:8];
	[_searchWithinComboBox setNumberOfVisibleItems:8];
}

- (void)_updateComboBox:(NSComboBox*)box with:(NSString*)text
{
	NSArray* values = [box objectValues];
	
	NSUInteger i = [values indexOfObject:text];
	if (i == NSNotFound)
	{
		[box insertItemWithObjectValue:text atIndex:0];
		
		NSInteger max = [AppSettings intValue:@"NumFindItems" missing:8];
		while (box.numberOfItems > max)
		{
			[box removeItemAtIndex:box.numberOfItems-1];
		}
	}
	else if (i != 0)
	{
		[box removeItemAtIndex:(NSInteger) i];
		[box insertItemWithObjectValue:text atIndex:0];
	}
}

static NSArray* intersectElements(NSArray* lhs, NSArray* rhs)
{
	NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:lhs.count];
	
	for (NSUInteger i = 0; i < lhs.count; ++i)
	{
		NSString* element = lhs[i];
		if ([element caseInsensitiveCompare:@"everything"] == NSOrderedSame)
		{
			[result addObject:element];			
		}
		else
		{
			for (NSUInteger j = 0; j < rhs.count; ++j)
			{
				NSString* candidate = rhs[j];
				if ([element caseInsensitiveCompare:candidate] == NSOrderedSame)
				{
					[result addObject:element];
					break;
				}
			}
		}
	}
	
	return result;
}

- (bool)singleFile
{
	return true;
}

- (void)_settingsChanged:(NSNotification*)notification
{
	UNUSED(notification);

	NSString* oldSelection = [_searchWithinComboBox stringValue];
	
	NSArray* patterns;
	BaseTextController* controller = [BaseTextController frontmost];
	if (controller && controller.language)
	{
		NSArray* elements = controller.language.styler.names;
		patterns = [AppSettings stringValues:@"SearchWithin"];
		patterns = intersectElements(patterns, elements);
		
		[_searchWithinComboBox removeAllItems];
		[_searchWithinComboBox addItemsWithObjectValues:patterns];
		
	}
	else if (self.singleFile)
	{
		patterns = [NSArray new];
		[_searchWithinComboBox removeAllItems];
	}
	else
	{
		// If the controller is for find/replace in files we don't want to zap
		// the search within dropdown every time the user switches to something
		// like the transcript window.
		return;
	}
	
	// If the new search within strings include whatever the user
	// was using then keep on using that.
	NSInteger i = [_searchWithinComboBox indexOfItemWithObjectValue:oldSelection];
	if (i != NSNotFound)
	{
		[_searchWithinComboBox setStringValue:oldSelection];
		[_searchWithinComboBox selectItemAtIndex:i];
	}
	// If not then chances are that the user doesn't want to use that
	// string (it probably doesn't make sense for the directory the
	// user switched to). So switch to the first string.
	else if (patterns.count > 0)
	{
		[_searchWithinComboBox setStringValue:patterns[0]];
		[_searchWithinComboBox selectItemAtIndex:0];
	}
	// Finally if we have nothing to select (very unlikely) then
	// just search within everything.
	else
	{
		[_searchWithinComboBox setStringValue:@"everything"];
	}
}

- (NSString*)findText
{
	return self.findComboBox.stringValue;
}

- (void)setFindText:(NSString*)text
{
	if (self.useRegexCheckBox.state == NSOnState)
	{
		text = [NSRegularExpression escapedPatternForString:text];
		text = [text stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
	}
	
	[self.findComboBox setStringValue:text];
	[self _enableButtons];
}

- (NSString*)replaceText
{
	NSString* text = self.replaceWithComboBox.stringValue;
	
	return text;
}

// This isn't used atm, may well be incorrect.
- (void)setReplaceText:(NSString*)text
{
	text = [text stringByReplacingOccurrencesOfString:@"\\'" withString:@"\\\\"];
	if (self.useRegexCheckBox.state == NSOnState)
		text = [NSRegularExpression escapedTemplateForString:text];
	
	[self.replaceWithComboBox setStringValue:text];
	[self _enableButtons];
}

- (NSString*)searchWithinText
{
	return [self.searchWithinComboBox.value description];
}

- (void)setSearchWithinText:(NSString*)text
{
	[self.searchWithinComboBox setStringValue:text];
}

- (bool)_findEnabled
{
	return self.findText.length > 0;
}

- (bool)_replaceEnabled
{
	return false;
}

- (void)_enableButtons
{
	ASSERT(false);	// subclasses implement this
}

- (bool)_rangeMatches:(NSRange)range controller:(BaseTextController*)controller
{
	bool matches = true;
	
	if (controller && controller.language && [_searchWithinComboBox.stringValue compare:@"everything"] != NSOrderedSame)
	{
		if ([controller respondsToSelector:@selector(getElementNameFor:)])
		{
			id obj = controller;
			NSString* element = [obj getElementNameFor:range];
			matches = element != nil && [element caseInsensitiveCompare:_searchWithinComboBox.stringValue] == NSOrderedSame;
		}
	}
	
	return matches;
}

- (void)_replace:(BaseTextController*)controller regex:(NSRegularExpression*)regex match:(NSTextCheckingResult*)match with:(NSString*)template showSelection:(bool)showSelection
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

- (void)_showSelection:(NSRange)range in:(BaseTextController*)controller
{
	[controller.window makeKeyAndOrderFront:self];
	[[controller getTextView] setSelectedRange:range];
	[[controller getTextView] scrollRangeToVisible:range];
	[[controller getTextView] showFindIndicatorForRange:range];
}

- (NSRegularExpression*)_getRegex
{
	NSRegularExpression* regex = nil;
	
	NSString* pattern = [self _getFindPattern];
	if ([pattern compare:_cachedPattern] == NSOrderedSame)
	{
		regex = _cachedRegex;
	}
	else
	{
		NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;
		if (_caseSensitiveCheckBox.state == NSOffState)
			options |= NSRegularExpressionCaseInsensitive;

		NSError* error = nil;
		regex = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:&error];
		
		if (regex)
		{
			_cachedRegex = regex;
			_cachedPattern = pattern;
		}
		else
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Failed compiling find regex '%@': %@", pattern, reason];
			[TranscriptController writeError:mesg];
		}
	}
	
	return regex;
}

- (NSString*)_getFindPattern
{
	NSString* pattern = self.findText;
	
	if (_useRegexCheckBox.state == NSOffState)
	{
		// If use regex is off then we want to escape almost all meta-characters
		// except for a few patterns that are really nice to have even when not
		// doing regex searches.
		pattern = [NSRegularExpression escapedPatternForString:pattern];
		pattern = [pattern stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
		pattern = [pattern stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
		pattern = [pattern stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
		pattern = [pattern stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];
		pattern = [pattern stringByReplacingOccurrencesOfString:@"#" withString:@"\\#"];
	}
	
	if (_matchEntireWordCheckBox.state == NSOnState && pattern.length > 0)
	{
		unichar first = [pattern characterAtIndex:0];
		unichar last = [pattern characterAtIndex:pattern.length-1];
		
		if ([[NSCharacterSet letterCharacterSet] characterIsMember:first])
			pattern = [@"\\b" stringByAppendingString:pattern];
		if ([[NSCharacterSet letterCharacterSet] characterIsMember:last])
			pattern = [pattern stringByAppendingString:@"\\b"];
	}
	
	LOG_DEBUG("Text", "finding with '%s'", STR(pattern));
	
	return pattern;
}

static unichar parseHexChar(NSString* text, NSUInteger i)
{
	unichar ch = [text characterAtIndex:i];
	
	if (ch >= '0' && ch <= '9')
		return ch - '0';
	
	else if (ch >= 'a' && ch <= 'f')
		return 10 + ch - 'a';
	
	else if (ch >= 'A' && ch <= 'F')
		return 10 + ch - 'A';

	else
		ASSERT(false);
}

- (NSString*)_replaceAsciiEscapes:(NSString*)str
{
	if (!_asciiRegex)
	{
		NSError* error = nil;
		_asciiRegex = [NSRegularExpression regularExpressionWithPattern:@"\\\\x([0-9a-fA-F]{2})" options:0 error:&error];
		ASSERT(_asciiRegex);
	}
	
	NSMutableString* result = [str mutableCopy];
	NSArray* matches = [_asciiRegex matchesInString:str options:0 range:NSMakeRange(0, str.length)];
	if (matches && matches.count > 0)
	{
		for (NSUInteger i = matches.count - 1; i < matches.count; --i)
		{
			NSTextCheckingResult* match = matches[i];
			NSRange range = [match rangeAtIndex:1];
			unichar ch = 16*parseHexChar(str, range.location) + parseHexChar(str, range.location + 1);
			
			range = [match rangeAtIndex:0];
			[result deleteCharactersInRange:range];
			[result insertString:[NSString stringWithCharacters:&ch length:1] atIndex:range.location];
		}
	}
	
	return result;
}

- (NSString*)_replaceUniEscapes:(NSString*)str
{
	if (!_uniRegex)
	{
		NSError* error = nil;
		_uniRegex = [NSRegularExpression regularExpressionWithPattern:@"\\\\u([0-9a-fA-F]{4})" options:0 error:&error];
		ASSERT(_uniRegex);
	}
	
	NSMutableString* result = [str mutableCopy];
	NSArray* matches = [_uniRegex matchesInString:str options:0 range:NSMakeRange(0, str.length)];
	if (matches && matches.count > 0)
	{
		for (NSUInteger i = matches.count - 1; i < matches.count; --i)
		{
			NSTextCheckingResult* match = matches[i];
			NSRange range = [match rangeAtIndex:1];
			unichar ch = 16*16*16*parseHexChar(str, range.location) + 16*16*parseHexChar(str, range.location + 1) + 16*parseHexChar(str, range.location + 2) + parseHexChar(str, range.location + 3);
			
			range = [match rangeAtIndex:0];
			[result deleteCharactersInRange:range];
			[result insertString:[NSString stringWithCharacters:&ch length:1] atIndex:range.location];
		}
	}
	
	return result;
}

- (NSString*)_getReplaceTemplate
{
	NSString* template = self.replaceText;
	
	template = [template stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
	template = [template stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
	template = [template stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];

	// Replacement templates don't support character escapes (\u and \x) which
	// is rather annoying.
	template = [self _replaceAsciiEscapes:template];
	template = [self _replaceUniEscapes:template];
	
	LOG_DEBUG("Text", "replacing with '%s'", STR(template));
	
	return template;
}

@end
