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

@end
