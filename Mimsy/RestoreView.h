#import <Foundation/Foundation.h>

@class TextController;

// Used to restore the view settings (e.g. scroller and selection) to that which
// was used when the document was last closed or to select (and show) a new
// range after the document is opened. Note that this has to be done after the
// text is laid out so that restoring the selection or calling scrollRangeToVisible
// works correctly. (Using a class here makes it easier to do nothing once the
// view has ben restored).
@interface RestoreView : NSObject

- (id)init:(TextController*)controller;

- (void)setPath:(NSString*)path;

// Scrolls the character range [begin, end) into view and displays the find
// indicator for the [begin, begin + count) characters.
- (void)showLineBegin:(NSUInteger)begin end:(NSUInteger)end count:(NSUInteger)count;

// Scrolls the character range into view and displays the find indicator for it.
- (void)showSelection:(NSRange)range;

// This is where the scrolling actually happens. Returns true if layout
// proceeded far enough for the view to be restored.
- (bool)onCompletedLayout:(NSLayoutManager*)layout atEnd:(bool)end;

@end
