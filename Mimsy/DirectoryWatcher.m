#import "DirectoryWatcher.h"

static void Callback(ConstFSEventStreamRef streamRef, void* clientCallBackInfo, size_t numEvents, void* eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);

@implementation DirectoryWatcher
{
	FSEventStreamRef _stream;
	NSArray* _watching;
	DirectoryWatcherCallback _callback;
}

- (id)initWithPath:(NSString*)path latency:(double)latency block:(void (^)(NSArray* paths))block
{
	_watching = @[path];
	_callback = block;
	
	FSEventStreamContext context = {.version = 0, .info = (__bridge void*)(self), .retain = NULL, .release = NULL, .copyDescription = NULL};
	_stream = FSEventStreamCreate(NULL, Callback, &context, (__bridge CFArrayRef) _watching, kFSEventStreamEventIdSinceNow, latency, kFSEventStreamCreateFlagUseCFTypes);
	
	FSEventStreamScheduleWithRunLoop(_stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
	bool started = FSEventStreamStart(_stream);
	if (!started)
	{
		FSEventStreamInvalidate(_stream);
		FSEventStreamRelease(_stream);
	}
	return started ? self : nil;
}

- (void)dealloc
{
	FSEventStreamStop(_stream);
	FSEventStreamInvalidate(_stream);
	FSEventStreamRelease(_stream);
}

// Note that this is called from the run loop so it is not threaded.
static void Callback(ConstFSEventStreamRef stream, void* refcon, size_t numEvents, void* inPaths, const FSEventStreamEventFlags flags[], const FSEventStreamEventId ids[])
{
	(void) stream;
	(void) numEvents;
	(void) flags;
	(void) ids;
	
	DirectoryWatcher* watcher = (__bridge DirectoryWatcher*)refcon;
	NSArray* paths = (__bridge NSArray*)inPaths;
	
	watcher.callback(paths);
}

@end
