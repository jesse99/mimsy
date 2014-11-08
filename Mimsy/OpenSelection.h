#import <AppKit/AppKit.h>

bool openTextRange(NSTextStorage* storage, NSRange range);

// Use -1 for line and col if they are unknown.
bool openFile(NSString* fileOrPath, int line, int col);