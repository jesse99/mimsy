// Generated using `./Mimsy/create-vector.py --element=NSRange --struct=RangeVector --size=NSUInteger` on 15 June 2014 01:42.
#import "Assert.h"
#import <stdlib.h>		// for malloc and free
#import <string.h>		// for memcpy

struct RangeVector
{
	NSRange* data;				// read/write
	NSUInteger count;		// read-only
	NSUInteger capacity;	// read-only
};

static inline struct RangeVector newRangeVector()
{
	struct RangeVector vector;

	vector.capacity = 16;
	vector.count = 0;
	vector.data = malloc(vector.capacity*sizeof(NSRange));

	return vector;
}

static inline void freeRangeVector(struct RangeVector* vector)
{
	// Vectors are often passed around via pointer because it should be
	// slightly more efficient but typically are not heap allocated.
	free(vector->data);
}

static inline void reserveRangeVector(struct RangeVector* vector, NSUInteger capacity)
{
	ASSERT(vector->count <= vector->capacity);

	if (capacity > vector->capacity)
	{
		NSRange* data = calloc(capacity*sizeof(NSRange), 1);	
		memcpy(data, vector->data, vector->count*sizeof(NSRange));

		free(vector->data);
		vector->data = data;
		vector->capacity = capacity;
	}
}
	
// If the vector is grown the new elements will be zero initialized.
static inline void setSizeRangeVector(struct RangeVector* vector, NSUInteger newSize)
{
	reserveRangeVector(vector, newSize);
	vector->count = newSize;
}

static inline void pushRangeVector(struct RangeVector* vector, NSRange element)
{
	if (vector->count == vector->capacity)
		reserveRangeVector(vector, 2*vector->capacity);

	ASSERT(vector->count < vector->capacity);
	vector->data[vector->count++] = element;
}
	
static inline NSRange popRangeVector(struct RangeVector* vector)
{
	ASSERT(vector->count > 0);
	return vector->data[--vector->count];
}
	
static inline void insertAtRangeVector(struct RangeVector* vector, NSUInteger index, NSRange element)
{
	ASSERT(index <= vector->count);

	if (vector->count == vector->capacity)
		reserveRangeVector(vector, 2*vector->capacity);
	
	memmove(vector->data + index + 1, vector->data + index, sizeof(NSRange)*(vector->count - index));
	vector->data[index] = element;
	++vector->count;
}

static inline void removeAtRangeVector(struct RangeVector* vector, NSUInteger index)
{
	ASSERT(index < vector->count);

	memmove(vector->data + index, vector->data + index + 1, sizeof(NSRange)*(vector->count - index - 1));
	--vector->count;
}

