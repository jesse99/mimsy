#import <Foundation/Foundation.h>

@class StyleRuns;

typedef void (^StylesCompleted)(StyleRuns* runs);

// This is the entry point that kicks off a task used to compute
// styles for a text document using a specified language.
@interface Styler : NSObject

// The completion handler is called on the main thread.
+ (void)computeStylesFor:(NSString*)language withText:(NSString*)text editCount:(NSUInteger)count completion:(StylesCompleted)callback;

@end

// this will need the file name
// if no styler was found still need to call the callback
// maybe rename this AsyncStyler

// when applying styles
// if editCount == 0 && !scrolled
//    apply styles from start to saved offset
// else
//    (re)sort runs based on current view point
//

// apply needs to enumerate styles for a fixed time period
