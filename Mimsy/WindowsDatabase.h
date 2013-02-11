#import <Foundation/Foundation.h>

struct WindowInfo
{
	NSRect frame;		// loscation and size of the client area of the window
	NSInteger length;	// number of characters in the document (used to detect modifications outside Mimsy)
	NSPoint origin;		// scrollbar positions
	NSRange selection;	// range of characters that were selected
	bool wordWrap;		// whether word wrap should be enabled
};

// Used to persist the frame and scroll bar position for text and directory windows.
// (Normally something like setFrameAutosaveName would be used instead, but we don't
// want to pollute the prefs file with potentially thousands of entries).
@interface WindowsDatabase : NSObject

// Returns false if the path cannot be found.
+ (bool)getInfo:(struct WindowInfo*)info forPath:(NSString*)path;

+ (void)saveInfo:(const struct WindowInfo*)info forPath:(NSString*)path;

@end
