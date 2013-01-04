#import "InfoController.h"

#import "Logger.h"
#import "TextDocument.h"

@implementation InfoController
{
	__weak TextDocument* _doc;
}

- (id)initFor:(TextDocument*)doc
{
	self = [super initWithWindowNibName:@"InfoWindow"];
	if (self)
	{
		_doc = doc;

		NSString* title = [_doc.displayName stringByAppendingString:@" Info"];
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
		
		[self _enableButtons];
		[self showWindow:self];
	}
    
    return self;
}

- (void)_enableButtons
{
	NSPopUpButton* button = self.lineEndian;
	if (button)
		[button setEnabled:_doc.format == PlainTextFormat];

	button = self.encoding;
	if (button)
		[button setEnabled:_doc.format == PlainTextFormat];
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

@end
