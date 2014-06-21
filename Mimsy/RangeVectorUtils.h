#import <Foundation/Foundation.h>
#import "RangeVector.h"

static inline int compareRanges(const void* inLhs, const void* inRhs)
{
	const NSRange* lhs = (const NSRange*) inLhs;
	const NSRange* rhs = (const NSRange*) inRhs;
	
	// First check the location,
	if (lhs->location < rhs->location)
		return -1;
	
	if (lhs->location > rhs->location)
		return +1;
	
	// if the locations are equal then check the lengths,
	if (lhs->length < rhs->length)
		return -1;
	
	if (lhs->length > rhs->length)
		return +1;
	
	return 0;
}

static inline int compareRangesWithIndex(const void* inIndex, const void* inRange)
{
	const NSRange* index = (const NSRange*) inIndex;
	const NSRange* range = (const NSRange*) inRange;
	
	if (index->location < range->location)
		return -1;

	if (index->location > range->location + range->length)
		return +1;
	
	return 0;
}

static inline void sortRangeVector(struct RangeVector* vector)
{
	qsort(vector->data, vector->count, sizeof(NSRange), compareRanges);
}

// Searches a sorted vector for a range containing index. If not found
// (NSNotFound, 0) is returned.
static inline NSRange indexSearchRangeVector(struct RangeVector* vector, NSUInteger index)
{
	NSRange key = NSMakeRange(index, 0);
	NSRange* range = (NSRange*) bsearch(&key, vector->data, vector->count, sizeof(NSRange), compareRangesWithIndex);
	return range ? *range : NSMakeRange(NSNotFound, 0);
}

// Returns an element that completely contains key or (NSNotFound, 0). The
// vector must be sorted.
static inline NSRange subsetRangeVector(struct RangeVector* vector, NSRange key)
{
	NSRange range = indexSearchRangeVector(vector, key.location);
	if (range.location != NSNotFound && key.location + key.length <= range.location + range.length)
		return range;
	else
		return NSMakeRange(NSNotFound, 0);
}

