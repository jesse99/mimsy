#import <Foundation/Foundation.h>

@class StyleRuns;

// Computes style runs using regexen from a language file.
@interface RegexStyler : NSObject

// Group N corresponds to elementNames[N] (elementNames[0] is the "Default" style).
- (id)initWithRegex:(NSRegularExpression*)regex elementNames:(NSArray*)names;

- (StyleRuns*)computeStyles:(NSString*)text editCount:(NSUInteger)count;

@end
