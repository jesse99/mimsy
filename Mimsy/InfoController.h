#import <Foundation/Foundation.h>

@class TextDocument;

// Used to display (and set) information related to the document,
// e.g. line ending and language.
@interface InfoController : NSWindowController

+ (InfoController*)openFor:(TextDocument*)doc;

@property (weak) IBOutlet NSPopUpButton* lineEndian;
@property (weak) IBOutlet NSPopUpButton* format;
@property (weak) IBOutlet NSPopUpButton* encoding;
@property (weak) IBOutlet NSPopUpButton *language;

- (IBAction)onEndianChanged:(NSPopUpButton*)button;
- (IBAction)onFormatChanged:(NSPopUpButton*)sender;
- (IBAction)onEncodingChanged:(NSPopUpButton*)sender;
- (IBAction)onLanguageChanged:(NSPopUpButton*)sender;

@end
