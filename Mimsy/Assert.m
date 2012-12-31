#import "Assert.h"

void _assertFailed(const char* fname, const char* file, int line, const char* expr)
{
	LOG_ERROR("%s ASSERT failed %s:%d: %s", fname, file, line, expr);
	abort();
}

void _assertMesg(const char* fname, const char* file, int line, const char* format, ...)
{
	char mesg[128];
	
	va_list args;
	va_start(args, format);
	vsnprintf(mesg, sizeof(mesg), format, args);
	va_end(args);

	LOG_ERROR("%s ASSERT failed %s:%d: %s", fname, file, line, mesg);
	abort();
}
