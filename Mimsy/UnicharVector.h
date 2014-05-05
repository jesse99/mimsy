// Generated using `./Mimsy/create-vector.py --element=unichar --struct=UnicharVector --size=NSUInteger` on 04 May 2014 01:27.
#import "Assert.h"
#import <stdlib.h>		// for malloc and free
#import <string.h>		// for memcpy

struct UnicharVector
{
	unichar* data;				// read/write
	NSUInteger count;		// read-only
	NSUInteger capacity;	// read-only
};

static inline struct UnicharVector newUnicharVector()
{
	struct UnicharVector vector;

	vector.capacity = 16;
	vector.count = 0;
	vector.data = malloc(vector.capacity*sizeof(unichar));

	return vector;
}

static inline void freeUnicharVector(struct UnicharVector* vector)
{
	// Vectors are often passed around via pointer because it should be
	// slightly more efficient but typically are not heap allocated.
	free(vector->data);
}

static inline void reserveUnicharVector(struct UnicharVector* vector, NSUInteger capacity)
{
	ASSERT(vector->count <= vector->capacity);

	if (capacity > vector->capacity)
	{
		unichar* data = calloc(capacity*sizeof(unichar), 1);	
		memcpy(data, vector->data, vector->count*sizeof(unichar));

		free(vector->data);
		vector->data = data;
		vector->capacity = capacity;
	}
}
	
// If the vector is grown the new elements will be zero initialized.
static inline void setSizeUnicharVector(struct UnicharVector* vector, NSUInteger newSize)
{
	reserveUnicharVector(vector, newSize);
	vector->count = newSize;
}

static inline void pushUnicharVector(struct UnicharVector* vector, unichar element)
{
	if (vector->count == vector->capacity)
		reserveUnicharVector(vector, 2*vector->capacity);

	ASSERT(vector->count < vector->capacity);
	vector->data[vector->count++] = element;
}
	
static inline unichar popUnicharVector(struct UnicharVector* vector)
{
	ASSERT(vector->count > 0);
	return vector->data[--vector->count];
}
	
static inline void insertAtUnicharVector(struct UnicharVector* vector, NSUInteger index, unichar element)
{
	ASSERT(index <= vector->count);

	if (vector->count == vector->capacity)
		reserveUnicharVector(vector, 2*vector->capacity);
	
	memmove(vector->data + index + 1, vector->data + index, sizeof(unichar)*(vector->count - index));
	vector->data[index] = element;
	++vector->count;
}

static inline void removeAtUnicharVector(struct UnicharVector* vector, NSUInteger index)
{
	ASSERT(index < vector->count);

	memmove(vector->data + index, vector->data + index + 1, sizeof(unichar)*(vector->count - index - 1));
	--vector->count;
}

