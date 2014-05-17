#import "BaseFindController.h"

#import "Assert.h"

@implementation BaseFindController

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
	if (self.useRegexCheckBox.integerValue)
	{
		text = [NSRegularExpression escapedPatternForString:text];
		text = [text stringByReplacingOccurrencesOfString:@"\t'" withString:@"\\t"];
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
	if (self.useRegexCheckBox.integerValue)
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

@end
