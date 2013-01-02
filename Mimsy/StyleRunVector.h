// Generated using `./Mimsy/create-vector.py --element=struct StyleRun --struct=StyleRunVector --size=NSUInteger --headers=StyleRun.h` on 01 January 2013 06:58.
#include "StyleRun.h"

#import "Assert.h"
#import <stdlib.h>		// for malloc and free
#import <string.h>		// for memcpy

struct StyleRunVector
{
	struct StyleRun* data;				// read/write
	NSUInteger count;		// read-only
	NSUInteger capacity;	// read-only
};

static inline struct StyleRunVector newStyleRunVector()
{
	struct StyleRunVector vector;

	vector.capacity = 16;
	vector.count = 0;
	vector.data = malloc(vector.capacity*sizeof(struct StyleRun));

	return vector;
}

static inline void freeStyleRunVector(struct StyleRunVector* vector)
{
	// Vectors are often passed around via pointer because it should be
	// slightly more efficient but typically are not heap allocated.
	free(vector->data);
}

static inline void reserveStyleRunVector(struct StyleRunVector* vector, NSUInteger capacity)
{
	ASSERT(vector->count <= vector->capacity);

	if (capacity > vector->capacity)
	{
		struct StyleRun* data = calloc(capacity*sizeof(struct StyleRun), 1);	
		memcpy(data, vector->data, vector->count*sizeof(struct StyleRun));

		free(vector->data);
		vector->data = data;
		vector->capacity = capacity;
	}
}
	
// If the vector is grown the new elements will be zero initialized.
static inline void setSizeStyleRunVector(struct StyleRunVector* vector, NSUInteger newSize)
{
	reserveStyleRunVector(vector, newSize);
	vector->count = newSize;
}

static inline void pushStyleRunVector(struct StyleRunVector* vector, struct StyleRun element)
{
	if (vector->count == vector->capacity)
		reserveStyleRunVector(vector, 2*vector->capacity);

	ASSERT(vector->count < vector->capacity);
	vector->data[vector->count++] = element;
}

static inline struct StyleRun popStyleRunVector(struct StyleRunVector* vector)
{
	ASSERT(vector->count > 0);
	return vector->data[--vector->count];
}

