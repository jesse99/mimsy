// Relatively simple logger that supports both log topics and log levels.
#import <Foundation/Foundation.h>

#undef LOG

extern const int ERROR_LEVEL;
extern const int WARN_LEVEL;
extern const int INFO_LEVEL;
extern const int DEBUG_LEVEL;

void setupLogging(const char* path);
void setTopicLevel(const char* topic, const char* level);
double getTime(void);
bool _shouldLog(const char* topic, int level);
void _doLog(const char* topic, const char* level, const char* format, va_list args);

static inline void LOG_ERROR(const char* topic, const char* format, ...) __printflike(2, 3);
static inline void LOG_WARN(const char* topic, const char* format, ...) __printflike(2, 3);
static inline void LOG_INFO(const char* topic, const char* format, ...) __printflike(2, 3);
static inline void LOG_DEBUG(const char* topic, const char* format, ...) __printflike(2, 3);
static inline void LOG(const char* topic, const char* format, ...) __printflike(2, 3);

static inline const char* STR(NSObject* object)
{
	return object.description.UTF8String;
}

static inline void LOG_ERROR(const char* topic, const char* format, ...)
{
	if (_shouldLog(topic, ERROR_LEVEL))
	{
		va_list args;
		va_start(args, format);
		_doLog(topic, "ERROR", format, args);
		va_end(args);
	}
}

static inline void LOG_WARN(const char* topic, const char* format, ...)
{
	if (_shouldLog(topic, WARN_LEVEL))
	{
		va_list args;
		va_start(args, format);
		_doLog(topic, "WARN", format, args);
		va_end(args);
	}
}

static inline void LOG_INFO(const char* topic, const char* format, ...)
{
	if (_shouldLog(topic, INFO_LEVEL))
	{
		va_list args;
		va_start(args, format);
		_doLog(topic, "INFO", format, args);
		va_end(args);
	}
}

static inline void LOG_DEBUG(const char* topic, const char* format, ...)
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
