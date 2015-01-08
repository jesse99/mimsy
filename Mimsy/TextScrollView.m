#import "TextScrollView.h"

@implementation TextScrollView

// This is where the subviews of the scroll view are laid out. We override it
// to make room for some widgets next to the horz scroller.
- (void)tile
{
    [super tile];
    
    if (self.lineButton == nil)
        self.lineButton = [self.superview viewWithTag:100];
    if (self.decsPopup == nil)
        self.decsPopup = [self.superview viewWithTag:101];
    
    NSScroller* horzScroller = self.horizontalScroller;
    NSRect horzFrame = horzScroller.frame;
    
    // Adjust the line label widget.
    NSRect localFrame = [self.lineButton.superview convertRect:horzFrame fromView:self];
    localFrame.size.width = self.lineButton.frame.size.width;
    
    horzFrame.origin.x += localFrame.size.width;
    horzFrame.size.width -= localFrame.size.width;
    
    [self.lineButton setFrame:localFrame];
    
    // Adjust the declarations popup widget.
    localFrame = [self.decsPopup.superview convertRect:horzFrame fromView:self];
    localFrame.size.width = self.decsPopup.frame.size.width;
    
    horzFrame.origin.x += localFrame.size.width;
    horzFrame.size.width -= localFrame.size.width;
    
    [self.decsPopup setFrame:localFrame];
    
    // Adjust the horizontal scrollbar.
    [horzScroller setFrame:horzFrame];
}

@end
