#import "InfoController.h"

#import "Language.h"
#import "Languages.h"
#import "Logger.h"
#import "TextController.h"
#import "TextDocument.h"

@implementation InfoController
{
	__weak TextDocument* _doc;
}

- (NSArray*)getHelpContext
{
	return @[@"info"];
}

- (id)initFor:(TextDocument*)doc
{
	self = [super initWithWindowNibName:@"InfoWindow"];
	if (self)
	{
		_doc = doc;

		NSString* title = [doc.displayName stringByAppendingString:@" Info"];
		[self.window setTitle:title];
		
		NSPopUpButton* button = self.lineEndian;
		if (button)
			[button selectItemAtIndex:(NSInteger)doc.endian];
		
		button = self.format;
		if (button)
			[button selectItemAtIndex:(NSInteger)doc.format];
		
		button = self.encoding;
		if (button)
			[button selectItemWithTag:(NSInteger)doc.encoding];
		
		button = self.language;
		if (button)
		{
			[button addItemWithTitle:@"None"];
			[Languages enumerate:
				^(Language* lang, bool* stop)
				{
					(void) stop;
					[button addItemWithTitle:lang.name];
				}
			];
			
			if (doc.controller.language)
				[button selectItemWithTitle:doc.controller.language.name];
			else
				[button selectItemWithTitle:@"None"];
		}
		
		[self _enableButtons];
		[self showWindow:self];
	}
    
    return self;
}

- (void)_enableButtons
{
	TextDocument* tmp = _doc;
	if (tmp)
	{
		NSPopUpButton* button = self.lineEndian;
		if (button)
			[button setEnabled:tmp.format == PlainTextFormat];
		
		button = self.encoding;
		if (button)
			[button setEnabled:tmp.format == PlainTextFormat];

		button = self.language;
		if (button)
			[button setEnabled:tmp.format == PlainTextFormat];
	}
}

+ (InfoController*)openFor:(TextDocument *)doc
{
	return [[InfoController alloc] initFor:doc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

- (IBAction)onEndianChanged:(NSPopUpButton*)button
{
	TextDocument* doc = _doc;
	if (doc)
		doc.endian = (LineEndian) button.selectedTag;
	[self _enableButtons];
}

- (IBAction)onFormatChanged:(NSPopUpButton*)button
{
	TextDocument* doc = _doc;
	if (doc)
		doc.format = (TextFormat) button.selectedTag;
	[self _enableButtons];
}

- (IBAction)onEncodingChanged:(NSPopUpButton*)button
{
	TextDocument* doc = _doc;
	if (doc)
		doc.encoding = (TextFormat) button.selectedTag;
	[self _enableButtons];
}

- (IBAction)onLanguageChanged:(NSPopUpButton*)button
{
	TextDocument* doc = _doc;
	if (doc)
		doc.controller.language = [Languages findWithlangName:button.selectedItem.title];
	[self _enableButtons];
}

@end
