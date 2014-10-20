#import <Foundation/Foundation.h>

@class TextController;

// Process StyleRun info derived from language files and map them to text
// attributes derived from a styles file.
@interface ApplyStyles : NSObject

- (id)init:(TextController*)controller;

- (void)resetStyles;

// Called with the start of a range which has been edited.
- (void)addDirtyLocation:(NSUInteger)loc reason:(NSString*)reason;

- (void)toggleBraceHighlightFrom:(NSUInteger)from to:(NSUInteger)to on:(bool)on;

// True if some styles were applied.
@property (readonly) bool applied;

@end
