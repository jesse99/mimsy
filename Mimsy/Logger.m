// Another approach is the Apple System Log facility, see http://boredzo.org/blog/archives/2008-01-20/why-asl
#import "Logger.h"
#import "Glob.h"

#import <sys/time.h>
#include <syslog.h>

const int MAX_TOPICS = 100;

static FILE* _file;
static double _time;
static Glob* _glob;

static size_t _topicWidth = 6;
static NSLock* _lock;

void setTopicGlob(Glob* glob)
{
	_glob = glob;
}

// This is kind of handy for timing stuff so we export it.
double getTime(void)
{
	struct timeval value;
	gettimeofday(&value, NULL);
	double secs = value.tv_sec + 1.0e-6*value.tv_usec;
	return secs - _time;
}

void setupLogging(const char* path)
{
	assert(_file == NULL);
	
	_file = fopen(path, "w");
	_time = getTime();
	_lock = [NSLock new];
	
	if (!_file)
	{
		syslog(LOG_ERR, "Couldn't open '%s': %s", path, strerror(errno));
	}
}

// We go with a blacklist of globs because we don't want a zillion logs
// to appear just because the user added a new extension.
bool _shouldLog(const char* topic)
{
	return _glob == nil || [_glob matchStr:topic] == 0;
}

void _doLog(const char* topic, const char* format, va_list args)
{
	[_lock lock];
	_topicWidth = MAX(strlen(topic), _topicWidth);
	
	fprintf(_file, "%.3f %-*s ", getTime(), (int) _topicWidth, topic);
	vfprintf(_file, format, args);
	fprintf(_file, "\n");
	fflush(_file);
	[_lock unlock];
}
