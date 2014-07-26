#import "UIntVector.h"

// Searches a sorted vector for the specified value. If value is in the vector then
// its index is returned. Otherwise the ones-complement of the vector index is returned
// where, if the value is inserted there, the vector remains sorted.
static inline NSUInteger searchUIntVector(struct UIntVector* vector, NSUInteger value)
{
	if (vector->count == 0)
		return ~((NSUInteger)0);

	NSUInteger minIndex = 0;
	NSUInteger maxIndex = vector->count - 1;

	while (true)
	{
		NSUInteger middleIndex = (minIndex + maxIndex)/2;
		NSUInteger candidate = vector->data[middleIndex];
		
		if (candidate == value)
			// We've found the value!
			return middleIndex;
		
		else if (minIndex >= maxIndex)
			// We're out of values to check.
			if (value < candidate)
				return ~middleIndex;
			else
				return ~(middleIndex+1);

		else if (candidate < value)
			// The middle value is too small so we need to try the upper sub-range.
			minIndex = middleIndex + 1;

		else
			// The middle value is too large so we need to try the lower sub-range.
			maxIndex = middleIndex - 1;
	}
}
