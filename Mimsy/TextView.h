#import <Foundation/Foundation.h>

@class TextController;

// Used to customize the behaviro of NSTextView within text document windows.
@interface TextView : NSTextView

- (void)onOpened:(TextController*)controller;

@end
