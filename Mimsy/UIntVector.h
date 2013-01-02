// Generated using `./Mimsy/create-vector.py --element=NSUInteger --struct=UIntVector --size=NSUInteger` on 01 January 2013 04:01.
#import "Assert.h"
#import <stdlib.h>		// for malloc and free
#import <string.h>		// for memcpy

struct UIntVector
{
	NSUInteger* data;				// read/write
	NSUInteger count;		// read-only
	NSUInteger capacity;	// read-only
};

static inline struct UIntVector newUIntVector()
{
	struct UIntVector vector;

	vector.capacity = 16;
	vector.count = 0;
	vector.data = malloc(vector.capacity*sizeof(NSUInteger));

	return vector;
}

static inline void freeUIntVector(struct UIntVector* vector)
{
	// Vectors are often passed around via pointer because it should be
	// slightly more efficient but typically are not heap allocated.
	free(vector->data);
}

static inline void reserveUIntVector(struct UIntVector* vector, NSUInteger capacity)
{
	ASSERT(vector->count <= vector->capacity);

	if (capacity > vector->capacity)
	{
		NSUInteger* data = malloc(capacity*sizeof(NSUInteger));	
		memcpy(data, vector->data, vector->count*sizeof(NSUInteger));

		free(vector->data);
		vector->data = data;
		vector->capacity = capacity;
	}
}

static inline void clearUIntVector(struct UIntVector* vector)
{
	vector->count = 0;
}

static inline void pushUIntVector(struct UIntVector* vector, NSUInteger element)
{
	if (vector->count == vector->capacity)
		reserveUIntVector(vector, 2*vector->capacity);

	ASSERT(vector->count < vector->capacity);
	vector->data[vector->count++] = element;
}

static inline NSUInteger popUIntVector(struct UIntVector* vector)
{
	ASSERT(vector->count > 0);
	return vector->data[--vector->count];
}

