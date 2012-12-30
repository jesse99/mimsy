#import "Logger.h"
#import <sys/time.h>

const int ERROR_LEVEL = 0;
const int WARN_LEVEL  = 1;
const int INFO_LEVEL  = 2;
const int DEBUG_LEVEL = 3;

static FILE* _file;
static double _time;

static double getTime(void)
{
	struct timeval value;
	gettimeofday(&value, NULL);
	double secs = value.tv_sec + 1.0e-6*value.tv_usec;
	
	double oldTime = _time;
	_time = secs;
	return secs - oldTime;
}

void setupLogging(void)
{
	assert(_file == NULL);
	
	const char* path = "/Volumes/SSD/mimsy/mimsy.log";
	_file = fopen(path, "w");
	getTime();
	
	if (!_file)
	{
		fprintf(stderr, "Couldn't open '%s': %s", path, strerror(errno));
	}
}

bool _shouldLog(const char* topic, int level)
{
	(void) topic;
	(void) level;
	return _file != NULL;
}

void _doLog(const char* topic, const char* level, const char* format, va_list args)
{
	fprintf(_file, "%.3f\t%s\t%s\t", getTime(), topic, level);
	if (strstr(format, "%@"))
		fprintf(_file, "%s", [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args].UTF8String);
	else
		vfprintf(_file, format, args);
	fprintf(_file, "\n");
	fflush(_file);
}

