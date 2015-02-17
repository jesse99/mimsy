#import <Foundation/Foundation.h>
#import "UIntVector.h"

@class StyleRuns;

// Computes style runs using regexen from a language file.
@interface RegexStyler : NSObject

// Initialized with an array of NSRrgularExpression followed by an array of element names.
// The two arrays must have the same size, though element names may be repeated.
- (id)initWithRegexen:(NSArray*)regexen elementNames:(NSArray*)names;

- (StyleRuns*)computeStyles:(NSString*)text editCount:(NSUInteger)count;

// Index zero will be the normal style.
@property (readonly) NSArray* names;

@end
