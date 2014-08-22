#import "Assert.h"

void _assertFailed(const char* fname, const char* file, int line, const char* expr)
{
	LOG("Error", "ASSERT(%s) %s:%d %s", expr, file, line, fname);
	abort();
}

void _assertMesg(const char* fname, const char* file, int line, const char* format, ...)
{
	char mesg[128];
	
	va_list args;
	va_start(args, format);
	vsnprintf(mesg, sizeof(mesg), format, args);
	va_end(args);

	LOG("Error", "ASSERT(%s) %s:%d %s", mesg, file, line, fname);
	abort();
}

@implementation AssertHandler

- (void)handleFailureInMethod:(SEL)selector object:(id)object file:(NSString *)fileName lineNumber:(NSInteger)line description:(NSString *)format,...
{
	(void) object;
	
	va_list args;
	va_start(args, format);
	NSString* mesg = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	
	_assertMesg(NSStringFromSelector(selector).UTF8String, fileName.UTF8String, (int) line, "%s", mesg.UTF8String);
}

- (void)handleFailureInFunction:(NSString *)functionName file:(NSString *)fileName lineNumber:(NSInteger)line description:(NSString *)format,...
{
	va_list args;
	va_start(args, format);
	NSString* mesg = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	
	_assertMesg(functionName.UTF8String, fileName.UTF8String, (int) line, "%s", mesg.UTF8String);
}

@end
