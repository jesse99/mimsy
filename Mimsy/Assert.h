// Unlike both NSAssert and assert this version:
// 1) Logs failures.
// 2) Defaults to working in release, but also has a debug only version.
//
// Unlike NSAssert this version:
// 3) Fails fast and hard (NSAsset does all kinds of crazy NSAssertionHandler nonsense).
// 4) Is easy to set a breakpoint within (by default NSAssert just bails after printing a stack trace).
//
// Unlike assert this version:
// 4) Is easy to set a breakpoint within (although assert, at least, drops you into the debugger when it fires).
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