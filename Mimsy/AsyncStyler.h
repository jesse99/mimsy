#import <Foundation/Foundation.h>

@class Language, StyleRuns;

typedef void (^StylesCompleted)(StyleRuns* runs);

// This is the entry point that kicks off a task used to compute
// styles for a text document using a specified language.
@interface AsyncStyler : NSObject

// The completion handler is called on the main thread.
+ (void)computeStylesFor:(Language*)lang withText:(NSString*)text editCount:(NSUInteger)count completion:(StylesCompleted)callback;

@end
