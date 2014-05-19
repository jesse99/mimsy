#import "BaseFindController.h"

#import "ArrayCategory.h"
#import "Assert.h"
#import "Constants.h"
#import "Language.h"
#import "Logger.h"
#import "RegexStyler.h"
#import "Settings.h"
#import "StringCategory.h"
#import "TextController.h"
#import "TranscriptController.h"

@implementation BaseFindController
{
	NSString* _cachedPattern;
	NSRegularExpression* _cachedRegex;
}

- (id)initWithWindowNibName:(NSString*)name
{
	self = [super initWithWindowNibName:name];
    if (self)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_settingsChanged:) name:@"SettingsChanged" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_settingsChanged:) name:NSWindowDidBecomeMainNotification object:nil];
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

- (void)_updateFindComboBox:(NSString*)text
{
	NSArray* values = [_findComboBox objectValues];
	
	NSUInteger i = [values indexOfObject:text];
	if (i == NSNotFound)
	{
		[_findComboBox insertItemWithObjectValue:text atIndex:0];
		
		NSInteger max = [Settings intValue:@"NumFindItems" missing:8];
		while (_findComboBox.numberOfItems > max)
		{
			[_findComboBox removeItemAtIndex:_findComboBox.numberOfItems-1];
		}
	}
	else if (i != 0)
	{
		[_findComboBox removeItemAtIndex:(NSInteger) i];
		[_findComboBox insertItemWithObjectValue:text atIndex:0];
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

- (void)_settingsChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
	NSString* oldSelection = [_searchWithinComboBox stringValue];
	
	NSArray* patterns;
	TextController* controller = [TextController frontmost];
	if (controller && controller.language)
	{
		NSArray* elements = controller.language.styler.names;
		patterns = [Settings stringValues:@"SearchWithin"];
		patterns = intersectElements(patterns, elements);
		
		[_searchWithinComboBox removeAllItems];
		[_searchWithinComboBox addItemsWithObjectValues:patterns];
		
	}
	else
	{
		patterns = [NSArray new];
		[_searchWithinComboBox removeAllItems];
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
		text = [text stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
		text = [text stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
	}
	
	[self.findComboBox setStringValue:text];
	[self _enableButtons];
}

- (NSString*)replaceText
{
	NSString* text = self.findComboBox.stringValue;
	
//	text = [text stringByReplacingOccurrencesOfString:@"\\'" withString:@"'"];
//	text = [text stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
//	text = [text stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
//	text = [text stringByReplacingOccurrencesOfString:@"\\f" withString:@"\f"];
//	text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\n"];
//	text = [text stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];
//	text = [text stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
//	text = [text stringByReplacingOccurrencesOfString:@"\\v" withString:@"\v"];

	return text;
}

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

- (bool)_rangeMatches:(NSRange)range
{
	bool matches = true;
	
	TextController* controller = [TextController frontmost];
	if (controller && controller.language && [_searchWithinComboBox.stringValue compare:@"everything"] != NSOrderedSame)
	{
		NSString* element = [controller getElementNameFor:range];
		matches = element != nil && [element caseInsensitiveCompare:_searchWithinComboBox.stringValue] == NSOrderedSame;
	}
	
	return matches;
}

- (NSRegularExpression*)_getRegex
{
	NSRegularExpression* regex = nil;
	
	NSString* pattern = [self _getRegexPattern];
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

- (NSString*)_getRegexPattern
{
	NSString* pattern = self.findText;
	
	if (_useRegexCheckBox.state == NSOffState)
	{
		pattern = [NSRegularExpression escapedPatternForString:pattern];
		pattern = [pattern stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
		pattern = [pattern stringByReplacingOccurrencesOfString:@"\\t" withString:@"	"];
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

@end
