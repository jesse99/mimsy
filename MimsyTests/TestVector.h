// Generated using `./Mimsy/create-vector.py --element=int --struct=TestVector --size=NSUInteger` on 01 January 2013 04:01.
#import "Assert.h"
#import <stdlib.h>		// for malloc and free
#import <string.h>		// for memcpy

struct TestVector
{
	int* data;				// read/write
	NSUInteger count;		// read-only
	NSUInteger capacity;	// read-only
};

static inline struct TestVector newTestVector()
{
	struct TestVector vector;

	vector.capacity = 16;
	vector.count = 0;
	vector.data = malloc(vector.capacity*sizeof(int));

	return vector;
}

static inline void freeTestVector(struct TestVector* vector)
{
	// Vectors are often passed around via pointer because it should be
	// slightly more efficient but typically are not heap allocated.
	free(vector->data);
}

static inline void reserveTestVector(struct TestVector* vector, NSUInteger capacity)
{
	ASSERT(vector->count <= vector->capacity);

	if (capacity > vector->capacity)
	{
		int* data = malloc(capacity*sizeof(int));	
		memcpy(data, vector->data, vector->count*sizeof(int));

		free(vector->data);
		vector->data = data;
		vector->capacity = capacity;
	}
}

static inline void clearTestVector(struct TestVector* vector)
{
	vector->count = 0;
}

static inline void pushTestVector(struct TestVector* vector, int element)
{
	if (vector->count == vector->capacity)
		reserveTestVector(vector, 2*vector->capacity);

	ASSERT(vector->count < vector->capacity);
	vector->data[vector->count++] = element;
}

static inline int popTestVector(struct TestVector* vector)
{
	ASSERT(vector->count > 0);
	return vector->data[--vector->count];
}

