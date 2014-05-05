// Generated using `./Mimsy/create-vector.py --element=int --struct=TestVector --size=NSUInteger` on 04 May 2014 01:24.
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
		int* data = calloc(capacity*sizeof(int), 1);	
		memcpy(data, vector->data, vector->count*sizeof(int));

		free(vector->data);
		vector->data = data;
		vector->capacity = capacity;
	}
}
	
// If the vector is grown the new elements will be zero initialized.
static inline void setSizeTestVector(struct TestVector* vector, NSUInteger newSize)
{
	reserveTestVector(vector, newSize);
	vector->count = newSize;
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
	
static inline void insertAtTestVector(struct TestVector* vector, NSUInteger index, int element)
{
	ASSERT(index <= vector->count);

	if (vector->count == vector->capacity)
		reserveTestVector(vector, 2*vector->capacity);
	
	memmove(vector->data + index + 1, vector->data + index, sizeof(int)*(vector->count - index));
	vector->data[index] = element;
	++vector->count;
}

static inline void removeAtTestVector(struct TestVector* vector, NSUInteger index)
{
	ASSERT(index < vector->count);

	memmove(vector->data + index, vector->data + index + 1, sizeof(int)*(vector->count - index - 1));
	--vector->count;
}

