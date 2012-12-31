// Unlike assert or NSAssert this version:
// 1) Logs failures.
// 2) Is compiled in in release.
// 3) Fails fast and hard.
#import "Logger.h"

void _assertFailed(const char* fname, const char* file, int line, const char* expr);
void _assertMesg(const char* fname, const char* file, int line, const char* format, ...) __printflike(4, 5);

#define	ASSERT(e) \
	(__builtin_expect(!(e), 0) ? _assertFailed(__func__, __FILE__, __LINE__, #e) : (void) 0)

#define ASSERT_MESG(format, ...)											\
	do																		\
	{																		\
		__PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS									\
		_assertMesg(__func__, __FILE__, __LINE__, format, ##__VA_ARGS__);	\
		__PRAGMA_POP_NO_EXTRA_ARG_WARNINGS									\
	} while(0)

// DEBUG_ASSERT is compiled out in release for when speed really matters.
#ifdef NDEBUG
	#define	DEBUG_ASSERT(e)	((void) 0)
#else
	#define	DEBUG_ASSERT(e) \
	(__builtin_expect(!(e), 0) ? _assertFailed(__func__, __FILE__, __LINE__, #e) : (void) 0)
#endif