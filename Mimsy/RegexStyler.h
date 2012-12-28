#import <Foundation/Foundation.h>

@class StyleRuns;

// Computes style runs using regexen from a language file.
@interface RegexStyler : NSObject

// Group N corresponds to elementNames[N-1] (groups are 1-based but names are 0-based).
- (id)initWithRegex:(NSRegularExpression*)regex elementNames:(NSArray*)names;

- (StyleRuns*)computeStyles:(NSString*)text editCount:(NSUInteger)count;

@end
