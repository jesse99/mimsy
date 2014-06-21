#import <Foundation/Foundation.h>
#import "StyleRunVector.h"

typedef id (^ElementToStyle)(NSString* elementName);

typedef void (^ProcessStyleRun)(NSUInteger elementIndex, id style, NSRange range, bool* stop);
typedef void (^ProcessStyleIndex)(NSUInteger elementIndex, NSRange range, bool* stop);

// Style runs computed for a text document. Once constructed it
// should only be used by the main thread. Note that there will
// be a style for every piece of text (text that doesn't match
// a language regex will be given the "Normal" style).
@interface StyleRuns : NSObject

- (id)initWithElementNames:(NSArray*)names runs:(struct StyleRunVector)runs editCount:(NSUInteger)count;

// The version of the document these runs were computed for.
@property (readonly) NSUInteger editCount;

// The number of unprocessed runs.
@property (readonly) NSUInteger length;

// Pre-computes style information (usually an NSDictionary) for
// each element name.
- (void)mapElementsToStyles:(ElementToStyle)block;

- (NSString*)indexToName:(NSUInteger)index;

// This is O(N).
- (NSUInteger)nameToIndex:(NSString*)name;

// Calls block until there are no more unprocessed runs or stop
// is set. As a side effect length is adjusted by the number of
// times block was called.
- (void)process:(ProcessStyleRun)block;

// Live the above except that styles are not passed into the block.
- (void)processIndexes:(ProcessStyleIndex)block;

@end
