#import <Foundation/Foundation.h>

@class TextController;

// Used to customize the behaviror of NSTextView within text document windows.
@interface TextView : NSTextView

- (void)onOpened:(TextController*)controller;

@property (readonly) bool restored;

@end
