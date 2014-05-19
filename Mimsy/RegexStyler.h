#import <Foundation/Foundation.h>
#import "UIntVector.h"

@class StyleRuns;

// Computes style runs using regexen from a language file.
@interface RegexStyler : NSObject

// The map maps capture group indexes to elementNames indexes.
- (id)initWithRegex:(NSRegularExpression*)regex elementNames:(NSArray*)names groupToName:(struct UIntVector)map;

- (StyleRuns*)computeStyles:(NSString*)text editCount:(NSUInteger)count;

@property (readonly) NSArray* names;

@end
