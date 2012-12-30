// Another approach is the Apple System Log facility, see http://boredzo.org/blog/archives/2008-01-20/why-asl
#import "Logger.h"

#import <sys/time.h>
#include <syslog.h>

const int ERROR_LEVEL = 1;
const int WARN_LEVEL  = 2;
const int INFO_LEVEL  = 3;
const int DEBUG_LEVEL = 4;

const int MAX_TOPICS = 100;

static FILE* _file;
static double _time;
static const char* _topics[MAX_TOPICS];
static int _levels[MAX_TOPICS];
static int _numTopics;

static int _topicWidth;
static int _levelWidth;

static double getTime(void)
{
	struct timeval value;
	gettimeofday(&value, NULL);
	double secs = value.tv_sec + 1.0e-6*value.tv_usec;
	return secs - _time;
}

// We want this to be fast because it is called by _shouldLog. One
// easy way to do this is to use a really simple hash map based on
// the first and last four characters in the topic (with an assert
// or something if the hashs collide). But it's unlikely that there
// will be more than ten or so topics so a linear search should be
// fine.
static int findTopic(const char* topic)
{
	for (int i = 0; i < _numTopics; ++i)
	{
		if (strcmp(topic, _topics[i]) == 0)
			return i;
	}
	
	return -1;
}

void setupLogging(const char* path)
{
	assert(_file == NULL);
	
	_file = fopen(path, "w");
	_time = getTime();
	
	if (!_file)
	{
		syslog(LOG_ERR, "Couldn't open '%s': %s", path, strerror(errno));
	}
}

void setTopicLevel(const char* topic, const char* level)
{
	int index = findTopic(topic);
	if (index < 0)
	{
		if (_numTopics == MAX_TOPICS)
		{
			LOG_ERROR("Mimsy", "More than %d log topics", MAX_TOPICS);
			return;
		}
		index = _numTopics++;
	}
	
	_topics[index] = strdup(topic);
	_topicWidth = MAX((int) strlen(topic), _topicWidth);
	_levelWidth = MAX((int) strlen(level), _levelWidth);
	
	if (strcmp(level, "DEBUG") == 0)
		_levels[index] = DEBUG_LEVEL;
	
	else if (strcmp(level, "INFO") == 0)
		_levels[index] = INFO_LEVEL;
	
	else if (strcmp(level, "WARN") == 0)
		_levels[index] = WARN_LEVEL;
	
	else if (strcmp(level, "ERROR") == 0)
		_levels[index] = ERROR_LEVEL;
	
	else
		LOG_ERROR("Mimsy", "Attempt to set %s topic to bogus level %s", topic, level);
}

bool _shouldLog(const char* topic, int level)
{
	int index = findTopic(topic);
	if (index >= 0)
	{
		return _file != NULL && level <= _levels[index];
	}
	else
	{
		LOG("Mimsy", "Topic %s was not in the logging.mimsy settings file", topic);
		setTopicLevel(topic, "INFO");
		return _file != NULL && level <= INFO_LEVEL;
	}
}

void _doLog(const char* topic, const char* level, const char* format, va_list args)
{
	fprintf(_file, "%.3f\t%-*s\t%-*s\t", getTime(), _topicWidth, topic, _levelWidth, level);
	if (strstr(format, "%@"))
		fprintf(_file, "%s", [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args].UTF8String);
	else
		vfprintf(_file, format, args);
	fprintf(_file, "\n");
	fflush(_file);
}

