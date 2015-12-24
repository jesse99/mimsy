/// Relatively simple logger that supports both log topics and log levels.
#import <Foundation/Foundation.h>

@class Glob;

void setupLogging(const char* path);
void setDontLogGlob(Glob* glob);
void setForceLogGlob(Glob* glob);
double getTime(void);
bool _shouldLog(const char* topic);
void _doLog(const char* topic, const char* format, va_list args);

static inline void LOG(const char* topic, const char* format, ...) __printflike(2, 3);
void SLOG(NSString* topic, NSString* text);

static inline const char* STR(NSObject* object)
{
	return object.description.UTF8String;
}

/// If you want to always log set the topic to the empty string.
/// This is a macro so that we can avoid evaluating the arguments
/// if _shouldLog returns false.
static inline void LOG(const char* topic, const char* format, ...)
{
	if (topic[0] == '\0' || _shouldLog(topic))
	{
		va_list args;
		va_start(args, format);
		_doLog(topic, format, args);
		va_end(args);
	}
}
