#import "BaseFindController.h"

#import "Assert.h"
#import "Logger.h"
#import "StringCategory.h"
#import "TranscriptController.h"

@implementation BaseFindController
{
	NSString* _cachedFindText;
	NSRegularExpression* _cachedRegex;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[self.window setExcludedFromWindowsMenu:TRUE];
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
	NSString* cachedText = self.findText;
	if (_caseSensitiveCheckBox.state == NSOnState)
		cachedText = [cachedText stringByAppendingString:@"-case_sensitive"];
	if (_matchEntireWordCheckBox.state == NSOnState)
		cachedText = [cachedText stringByAppendingString:@"-match_entire_word"];
	if (_useRegexCheckBox.state == NSOnState)
		cachedText = [cachedText stringByAppendingString:@"-use_regex"];
	
	if (cachedText == _cachedFindText)
		return _cachedRegex;
	
	NSString* pattern = [self _getRegexPattern];
	NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;
	if (_caseSensitiveCheckBox.state == NSOffState)
		options |= NSRegularExpressionCaseInsensitive;
	NSError* error = nil;
	_cachedRegex = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:&error];
	_cachedFindText = cachedText;
	
	if (!_cachedRegex)
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed compiling find regex '%@': %@", pattern, reason];
		[TranscriptController writeError:mesg];
	}
	
	return _cachedRegex;
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
	
	LOG_Debug("Text", "finding with '%s'", STR(pattern));
	
	return pattern;
}

@end
