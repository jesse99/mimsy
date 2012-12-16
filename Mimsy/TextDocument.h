#import <Cocoa/Cocoa.h>

typedef enum LineEndian : NSUInteger
{
	NoEndian,			// used for documents not read as text (e.g. Word)
	UnixEndian,			// "\n"
	MacEndian,			// "\r"
	WindowsEndian,		// "\r\n"
} LineEndian;

// Document object used when editing text documents.
@interface TextDocument : NSDocument

- (void) controllerDidLoad;
- (void) reloadIfChanged;

@property NSMutableAttributedString* text;		// note that this will be set to nil once the view is initialized
@property enum LineEndian endian;
@property NSStringEncoding encoding;			// will be zero for documents not read as text (e.g. Word)
@property bool binary;							// true if the file is intended to be viewed as binary data

@end
