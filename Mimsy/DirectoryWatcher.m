#import "DirectoryWatcher.h"

static void Callback(ConstFSEventStreamRef streamRef, void* clientCallBackInfo, size_t numEvents, void* eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);

@implementation DirectoryWatcher
{
	FSEventStreamRef _stream;
	NSArray* _watching;
	DirectoryWatcherCallback _callback;
}

- (id)initWithPath:(MimsyPath*)path latency:(double)latency block:(void (^)(MimsyPath* path, FSEventStreamEventFlags flags))block
{
	_watching = @[path.asString];
	_callback = block;
	
	FSEventStreamContext context = {.version = 0, .info = (__bridge void*)(self), .retain = NULL, .release = NULL, .copyDescription = NULL};
	_stream = FSEventStreamCreate(NULL, Callback, &context, (__bridge CFArrayRef) _watching, kFSEventStreamEventIdSinceNow, latency, kFSEventStreamCreateFlagUseCFTypes|kFSEventStreamCreateFlagFileEvents);
	
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

static NSString* getFlags(FSEventStreamEventFlags flags)
{
	NSMutableString* result = [NSMutableString new];
	
	if ((flags & kFSEventStreamEventFlagItemCreated) == kFSEventStreamEventFlagItemCreated)
		[result appendString:@"kFSEventStreamEventFlagItemCreated "];
	
	if ((flags & kFSEventStreamEventFlagItemRemoved) == kFSEventStreamEventFlagItemRemoved)
		[result appendString:@"kFSEventStreamEventFlagItemRemoved "];
	
	if ((flags & kFSEventStreamEventFlagItemRenamed) == kFSEventStreamEventFlagItemRenamed)
		[result appendString:@"kFSEventStreamEventFlagItemRenamed "];
	
	if ((flags & kFSEventStreamEventFlagItemModified) == kFSEventStreamEventFlagItemModified)
		[result appendString:@"kFSEventStreamEventFlagItemModified "];
	
	if ((flags & kFSEventStreamEventFlagItemInodeMetaMod) == kFSEventStreamEventFlagItemInodeMetaMod)
		[result appendString:@"kFSEventStreamEventFlagItemInodeMetaMod "];
	
	if ((flags & kFSEventStreamEventFlagItemFinderInfoMod) == kFSEventStreamEventFlagItemFinderInfoMod)
		[result appendString:@"kFSEventStreamEventFlagItemFinderInfoMod "];
	
	if ((flags & kFSEventStreamEventFlagItemXattrMod) == kFSEventStreamEventFlagItemXattrMod)
		[result appendString:@"kFSEventStreamEventFlagItemXattrMod "];
	
	if ((flags & kFSEventStreamEventFlagItemChangeOwner) == kFSEventStreamEventFlagItemChangeOwner)
		[result appendString:@"kFSEventStreamEventFlagItemChangeOwner "];
	
	if ((flags & kFSEventStreamEventFlagItemIsFile) == kFSEventStreamEventFlagItemIsFile)
		[result appendString:@"kFSEventStreamEventFlagItemIsFile "];
	
	if ((flags & kFSEventStreamEventFlagItemIsDir) == kFSEventStreamEventFlagItemIsDir)
		[result appendString:@"kFSEventStreamEventFlagItemIsDir "];
	
	if ((flags & kFSEventStreamEventFlagItemIsSymlink) == kFSEventStreamEventFlagItemIsSymlink)
		[result appendString:@"kFSEventStreamEventFlagItemIsSymlink "];
		
	return result;
}

// Note that this is called from the run loop so it is not threaded.
static void Callback(ConstFSEventStreamRef stream, void* refcon, size_t numEvents, void* inPaths, const FSEventStreamEventFlags flags[], const FSEventStreamEventId ids[])
{
	UNUSED(stream, ids);
	
	// These tend to constantly arrive. I think whenever the Finder or another process happens
	// to touch a file something like last access time gets set.
	FSEventStreamEventFlags blacklist = kFSEventStreamEventFlagItemModified | kFSEventStreamEventFlagItemInodeMetaMod |kFSEventStreamEventFlagItemIsFile;
	
	DirectoryWatcher* watcher = (__bridge DirectoryWatcher*)refcon;
	NSArray* paths = (__bridge NSArray*)inPaths;
	
	for (size_t i = 0; i < numEvents; ++i)
	{
        FSEventStreamEventFlags bits = flags[i];
		if (bits != blacklist)
		{
			LOG("Mimsy:Verbose", "%s %s", STR(paths[i]), STR(getFlags(bits)));
            
            // The whole point of this is to notify clients when something changed but when an item
            // is created or renamed clients can't tell what was changed so we need to tell them
            // that the parent directory was modified.
            MimsyPath* path = [[MimsyPath alloc] initWithString:paths[i]];
            if (bits & (kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRenamed)) {
                if (bits & kFSEventStreamEventFlagItemIsFile) {
                    bits &= ~(FSEventStreamEventFlags) (kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemIsFile);
                    bits |= kFSEventStreamEventFlagItemIsDir | kFSEventStreamEventFlagItemModified;
                } else {
                    bits &= ~(FSEventStreamEventFlags) (kFSEventStreamEventFlagItemCreated);
                    bits |= kFSEventStreamEventFlagItemModified;
                }
                path = [path popComponent];
            }
            
			watcher.callback(path, bits);
		}
	}
}

@end
