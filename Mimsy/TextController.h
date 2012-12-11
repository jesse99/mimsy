#import <Cocoa/Cocoa.h>

@interface TextController : NSWindowController
{
	IBOutlet NSTextView* theView;
}

- (NSTextView*) view;
@end
