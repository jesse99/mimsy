#import <Cocoa/Cocoa.h>

enum LineEndian
{
	UnixEndian,			// "\n"
	MacEndian,			// "\r"
	WindowsEndian,		// "\r\n"
};

// Document object used when editing text documents.
@interface TextDocument : NSDocument

- (void)controllerDidLoad;

@property NSMutableAttributedString* text;		// note that this will be set to nil once the view is initialized
@property enum LineEndian endian;

@end
