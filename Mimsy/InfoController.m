#import "InfoController.h"

#import "Logger.h"
#import "TextDocument.h"

@implementation InfoController
{
	__weak TextDocument* _doc;
}

- (id)initFor:(TextDocument*)doc title:(NSString*)title
{
	self = [super initWithWindowNibName:@"InfoWindow"];
	if (self)
	{
		_doc = doc;
		[self.window setTitle:title];
		
		NSPopUpButton* button = self.lineEndian;
		if (button)
			[button selectItemAtIndex:(NSInteger)doc.endian];
		
		[self showWindow:self];
	}
    
    return self;
}

+ (InfoController*)openFor:(TextDocument *)doc title:(NSString*)title
{
	return [[InfoController alloc] initFor:doc title:title];
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
}

@end
