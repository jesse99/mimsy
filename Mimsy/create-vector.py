#!/usr/bin/env python
# Cocoa's collection classes are rather annoying (and inefficient) when used
# with primitive types so we use this script to generated hard-coded ADTs
# for the handful of primitives we want to use in collections.
import datetime, sys

try:
	import argparse
except:
	sys.stderr.write("This script requires Python 2.7 or later\n")
	sys.exit(2)

# TODO: Need an --objc switch or something to toggle #imports on
# (and maybe to add a block enumerate).
Header = """#import "Assert.h"
#import <stdlib.h>		// for malloc and free
#import <string.h>		// for memcpy

struct {NAME}
{
	{TYPE}* data;				// read/write
	{SIZE} count;		// read-only
	{SIZE} capacity;	// read-only
};

static inline struct {NAME} new{NAME}()
{
	struct {NAME} vector;

	vector.capacity = 16;
	vector.count = 0;
	vector.data = malloc(vector.capacity*sizeof({TYPE}));

	return vector;
}

static inline void free{NAME}(struct {NAME}* vector)
{
	// Vectors are often passed around via pointer because it should be
	// slightly more efficient but typically are not heap allocated.
	free(vector->data);
}

static inline void reserve{NAME}(struct {NAME}* vector, {SIZE} capacity)
{
	ASSERT(vector->count <= vector->capacity);

	if (capacity > vector->capacity)
	{
		{TYPE}* data = calloc(capacity*sizeof({TYPE}), 1);	
		memcpy(data, vector->data, vector->count*sizeof({TYPE}));

		free(vector->data);
		vector->data = data;
		vector->capacity = capacity;
	}
}
	
/// If the vector is grown the new elements will be zero initialized.
static inline void setSize{NAME}(struct {NAME}* vector, {SIZE} newSize)
{
	reserve{NAME}(vector, newSize);
	vector->count = newSize;
}

static inline void push{NAME}(struct {NAME}* vector, {TYPE} element)
{
	if (vector->count == vector->capacity)
		reserve{NAME}(vector, 2*vector->capacity);

	ASSERT(vector->count < vector->capacity);
	vector->data[vector->count++] = element;
}
	
static inline {TYPE} pop{NAME}(struct {NAME}* vector)
{
	ASSERT(vector->count > 0);
	return vector->data[--vector->count];
}
	
static inline void insertAt{NAME}(struct {NAME}* vector, {SIZE} index, {TYPE} element)
{
	ASSERT(index <= vector->count);

	if (vector->count == vector->capacity)
		reserve{NAME}(vector, 2*vector->capacity);
	
	memmove(vector->data + index + 1, vector->data + index, sizeof({TYPE})*(vector->count - index));
	vector->data[index] = element;
	++vector->count;
}

static inline void removeAt{NAME}(struct {NAME}* vector, {SIZE} index)
{
	ASSERT(index < vector->count);

	memmove(vector->data + index, vector->data + index + 1, sizeof({TYPE})*(vector->count - index - 1));
	--vector->count;
}
"""

# TODO:
# Probably want an option for blocks (e.g. enumerate). Maybe also GCC's lexically scoped nested functions.
# May want a flag to control what happens with out of memory.

# Parse command line.
parser = argparse.ArgumentParser(description = "Generates type-safe C vector code.", epilog = "Note that the type must be a POD type. If it is not a POD utarray can be used (although that requires elements to be heap allocated).")
parser.add_argument("--element", metavar = "TYPE", required=True, help = 'the element type name')
parser.add_argument("--headers", metavar = "NAMES", help = 'space separated list of header names to include')
parser.add_argument("--size", metavar = "TYPE", help = 'size and capacity type [unsigned long]')
parser.add_argument("--struct", metavar = "TYPE", help = "the vector struct name [element.titleCase + 'Vector']")
parser.add_argument("--version", "-V", action='version', version='%(prog)s 0.1')
options = parser.parse_args()

if options.struct == None:
	options.struct = '%sVector' % options.element.capitalize()
if options.size == None:
	options.size = 'unsigned long'

# Generate the header.
print '// Generated using `%s` on %s.' % (' '.join(sys.argv), datetime.datetime.now().strftime("%d %B %Y %I:%M"))

if options.headers:
	for name in options.headers.split():
		print '#include "%s"' % name
	print

header = Header
header = header.replace('{TYPE}', options.element)
header = header.replace('{NAME}', options.struct)
header = header.replace('{SIZE}', options.size)
print header



# TODO:
# write a bash script to poop out
#    int version into tests
#    Run version into app
# write a test for the int version
# get rid of the ut collections
