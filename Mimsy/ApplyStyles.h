#import <Foundation/Foundation.h>

@class TextController;

// Process StyleRun info derived from language files and map them to text
// attributes derived from a styles file.
@interface ApplyStyles : NSObject

- (id)init:(TextController*)controller;

// Called with the start of a range which has been edited.
- (void)addDirtyLocation:(NSUInteger)loc;

@end
