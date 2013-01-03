#import <Foundation/Foundation.h>

@class TextDocument;

// Used to display (and set) information related to the document,
// e.g. line ending and language.
@interface InfoController : NSWindowController

+ (InfoController*)openFor:(TextDocument*)doc;

@property (weak) IBOutlet NSPopUpButton* lineEndian;

- (IBAction)onEndianChanged:(NSPopUpButton*)button;

@end
