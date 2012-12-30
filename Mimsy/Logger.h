// Relatively simple logger that supports both log topics and log levels.
#import <Foundation/Foundation.h>

#undef DEBUG

extern const int ERROR_LEVEL;
extern const int WARN_LEVEL;
extern const int INFO_LEVEL;
extern const int DEBUG_LEVEL;

void setupLogging(const char* path);
void setTopicLevel(const char* topic, const char* level);
bool _shouldLog(const char* topic, int level);
void _doLog(const char* topic, const char* level, const char* format, va_list args);

static inline void ERROR(const char* topic, const char* format, ...)
{
	if (_shouldLog(topic, ERROR_LEVEL))
	{
		va_list args;
		va_start(args, format);
		_doLog(topic, "ERROR", format, args);
		va_end(args);
	}
}

static inline void WARN(const char* topic, const char* format, ...)
{
	if (_shouldLog(topic, WARN_LEVEL))
	{
		va_list args;
		va_start(args, format);
		_doLog(topic, "WARN", format, args);
		va_end(args);
	}
}

static inline void INFO(const char* topic, const char* format, ...)
{
	if (_shouldLog(topic, INFO_LEVEL))
	{
		va_list args;
		va_start(args, format);
		_doLog(topic, "INFO", format, args);
		va_end(args);
	}
}

static inline void DEBUG(const char* topic, const char* format, ...)
{
	if (_shouldLog(topic, DEBUG_LEVEL))
	{
		va_list args;
		va_start(args, format);
		_doLog(topic, "DEBUG", format, args);
		va_end(args);
	}
}

static inline void LOG(const char* topic, const char* format, ...)
{
	va_list args;
	va_start(args, format);
	_doLog(topic, "     ", format, args);
	va_end(args);
}
