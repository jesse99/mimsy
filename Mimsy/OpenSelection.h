#import <AppKit/AppKit.h>
#import "MimsyPlugins.h"

bool openLocalPath(MimsyPath* path);

bool openTextRange(NSTextStorage* storage, NSRange range);

/// This is used to open an arbitrary string which may be a path or an URL.
bool openPath(NSString* path);
