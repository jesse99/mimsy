#import "BaseFindController.h"

#import "Assert.h"
#import "Constants.h"
#import "Logger.h"
#import "Settings.h"
#import "StringCategory.h"
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
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_settingsChanged:) name:@"CurrentDirectoryChanged" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_settingsChanged:) name:@"SettingsChanged" object:nil];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[self.window setExcludedFromWindowsMenu:TRUE];
	[self _settingsChanged:nil];
}

- (void)_settingsChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
	NSString* oldSelection = [_searchWithinComboBox stringValue];
	
	NSArray* patterns = [Settings stringValues:@"SearchWithin"];
	[_searchWithinComboBox removeAllItems];
	[_searchWithinComboBox addItemsWithObjectValues:patterns];
	
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
		[_searchWithinComboBox setStringValue:@"..."];
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

- (NSRegularExpression*)_getRegex
{
	NSRegularExpression* regex = nil;
	
	NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;
	NSString* pattern = [self _getRegexPattern:&options];
	if ([pattern compare:_cachedPattern] == NSOrderedSame)
	{
		regex = _cachedRegex;
	}
	else
	{
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

- (NSString*)_getRegexPattern:(NSRegularExpressionOptions*)options
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
	
	if ([_searchWithinComboBox.stringValue compare:@"..."] != NSOrderedSame)
		pattern = [self _getSearchWithinPattern:pattern options:options];
	
	LOG_DEBUG("Text", "finding with '%s'", STR(pattern));
	
	return pattern;
}

- (NSString*)_getSearchWithinPattern:(NSString*)pattern options:(NSRegularExpressionOptions*)options
{
	NSString* within = _searchWithinComboBox.stringValue;
	NSRange range = [within rangeOfString:EllipsisChar];
	if (range.location == NSNotFound)
	{
		[TranscriptController writeError:@"Search within pattern has no ellipsis"];
		return pattern;
	}
	
	NSString* prefix = [NSRegularExpression escapedPatternForString:[within substringToIndex:range.location]];
	NSString* suffix = [NSRegularExpression escapedPatternForString:[within substringFromIndex:range.location+1]];
	
	NSString* result = @"";
	
	if (prefix.length > 0)
	{
		// zero width match of prefix
		result = [result stringByAppendingFormat:@"(?<= %@", prefix];
		
		// match zero or more characters, but not the suffix
		if (suffix.length > 0 && [prefix compare:suffix] != NSOrderedSame)
			result = [result stringByAppendingFormat:@"(?:.(?!%@))*?)", suffix];
		else
			result = [result stringByAppendingString:@".*?)"];
	}
	
	// match the user's re
	result = [result stringByAppendingString:pattern];
	
	if (suffix.length > 0)
	{
		// match zero or more characters, but not the prefix
		if (prefix.length > 0 && [prefix compare:suffix] != NSOrderedSame)
			result = [result stringByAppendingFormat:@"(?=(?:.(?!%@))*?", prefix];
		else
			result = [result stringByAppendingString:@"(?=.*?"];
		
		// zero width match the suffix
		result = [result stringByAppendingFormat:@"%@)", suffix];
	}
	
	// If we can distinguish between the prefix and the suffix then allow
	// . to match new lines.
	if (prefix.length > 0 && suffix.length > 0 && [prefix compare:suffix] != NSOrderedSame)
		*options |= NSRegularExpressionDotMatchesLineSeparators;
	
	return result;
}

@end
