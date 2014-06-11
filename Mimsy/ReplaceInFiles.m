#import "ReplaceInFiles.h"

#import "AppSettings.h"
#import "Assert.h"
#import "Decode.h"
#import "FindInFilesController.h"
#import "Glob.h"
#import "Logger.h"
#import "StringCategory.h"
#import "TextController.h"
#import "TranscriptController.h"

@implementation ReplaceInFiles
{
	FindInFilesController* _findController;
	NSRegularExpression* _regex;
	NSString* _template;
	NSString* _findText;
	
	NSString* _root;
	Glob* _includeGlobs;
	Glob* _excludeGlobs;
	Glob* _excludeAllGlobs;
	
	NSUInteger _openFiles;
	NSUInteger _openMatches;
	int32_t _unopenedFiles;
	int32_t _unopenedMatches;
	int32_t _numThreads;
}

- (id)init:(FindInFilesController*)controller path:(NSString*)path template:(NSString*)template
{
	self = [super init];
	
	if (self)
	{
		_findController = controller;
		_root = path;
		_regex = [controller _getRegex];	// note that NSRegularExpression is documented to be thread safe
		_template = template;
		_findText = controller.findText;
		
		NSArray* globs = [controller.includedGlobsComboBox.stringValue splitByString:@" "];
		_includeGlobs = [[Glob alloc] initWithGlobs:globs];
		
		globs = [controller.excludedGlobsComboBox.stringValue splitByString:@" "];
		_excludeGlobs = [[Glob alloc] initWithGlobs:globs];
		
		globs = [[AppSettings stringValue:@"FindAllAlwaysExclude" missing:@""] splitByString:@" "];
		_excludeAllGlobs = [[Glob alloc] initWithGlobs:globs];
	}
	
	return self;
}

- (void)replaceAll
{
	[self step1];
}

// We do as much work as we can off the main thread so these functions chain
// into one another executing within different threads.
// 1) snapshot paths for all the open windows
- (void)step1
{
	NSMutableDictionary* allOpenPaths = [NSMutableDictionary new];	// path => TextController
	
	[TextController enumerate:
		 ^(TextController *controller)
		 {
			 if (controller.path)
				 allOpenPaths[controller.path] = controller;
		 }];
	
	dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(concurrent,
	   ^{
		   if ([_root compare:@"Open Windows"] == NSOrderedSame)
			   [self step2WithOnlyOpenPaths:allOpenPaths];
		   else
			   [self step2WithOpenPaths:allOpenPaths];
	   });
}

// 2) get a list of paths to the files we need to process
// in the main thread and a worker thread
- (void)step2WithOnlyOpenPaths:(NSDictionary*)allOpenPaths	// threaded
{
	NSMutableDictionary* openPaths = [NSMutableDictionary new];	// path => TextController
	
	for (NSString* path in allOpenPaths)
	{
		NSString* fileName = [path lastPathComponent];
		if ([_includeGlobs matchName:fileName])
		{
			TextController* controller = [allOpenPaths valueForKey:path];
			if (controller)
				openPaths[path] = controller;
		}
	}
	
	if (openPaths.count > 0)
	{
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_async(main,
		   ^{
			   [self _step3aWithOpenPaths:openPaths];
		   });
	}
}

// 2) get a list of paths to the files we need to process
// in the main thread and a worker thread
- (void)step2WithOpenPaths:(NSDictionary*)allOpenPaths	// threaded
{
	NSMutableDictionary* openPaths = [NSMutableDictionary new];	// path => TextController
	NSMutableArray* unopenedPaths = [NSMutableArray new];		// paths
	
	NSFileManager* fm = [NSFileManager new];
	NSMutableArray* dirPaths = [NSMutableArray new];
	[dirPaths addObject:_root];
	while (dirPaths.count > 0)
	{
		NSString* directory = [dirPaths lastObject];
		[dirPaths removeLastObject];
		
		NSError* error = nil;
		NSArray* items = [fm contentsOfDirectoryAtPath:directory error:&error];
		if (items)
		{
			for (NSString* item in items)
			{
				NSString* path = [directory stringByAppendingPathComponent:item];
				if (![_excludeGlobs matchName:item] && ![_excludeAllGlobs matchName:item])
				{
					BOOL isDirectory = FALSE;
					if ([fm fileExistsAtPath:path isDirectory:&isDirectory])
					{
						if (isDirectory)
						{
							[dirPaths addObject:path];
						}
						else if ([_includeGlobs matchName:item])
						{
							TextController* controller = [allOpenPaths valueForKey:path];
							if (controller)
								openPaths[path] = controller;
							else
								[unopenedPaths addObject:path];
						}
					}
				}
			}
		}
		else
		{
			dispatch_queue_t main = dispatch_get_main_queue();
			dispatch_async(main,
			   ^{
				   NSString* reason = [error localizedFailureReason];
				   NSString* mesg = [NSString stringWithFormat:@"Error walking '%@': %@", directory, reason];
				   [TranscriptController writeError:mesg];
			   });
		}
	}
	
	_numThreads = 0;
	if (unopenedPaths.count > 0)	// do this before the dispatching to avoid races
		_numThreads += 2;
	if (openPaths.count > 0)
		_numThreads += 1;
	
	if (unopenedPaths.count > 0)
	{
		NSUInteger middle = unopenedPaths.count/2;
		
		dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrent,
		   ^{
			   [self _step3bWithUnopenedPaths:unopenedPaths begin:0 end:middle];
		   });
		dispatch_async(concurrent,
		   ^{
			   [self _step3bWithUnopenedPaths:unopenedPaths begin:middle end:unopenedPaths.count];
		   });
	}
	
	if (openPaths.count > 0)
	{
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_async(main,
		   ^{
			   [self _step3aWithOpenPaths:openPaths];
		   });
	}
}

// 3a) process the windows which were open
- (void)_step3aWithOpenPaths:(NSDictionary*)paths
{
	for (NSString* path in paths)
	{
		TextController* textController = paths[path];
		_openMatches += replaceAll(_findController, textController, _regex, _template);
	}
	
	_openFiles = paths.count;
	[self _onFinishedThread];
}

// 3b) process files on disk
- (void)_step3bWithUnopenedPaths:(NSArray*)paths begin:(NSUInteger)begin end:(NSUInteger)end	// threaded
{
	for (NSUInteger i = begin; i < end; ++i)
	{
		NSString* path = paths[i];
		[self _processPath:path];
	}
	
	OSAtomicAdd32Barrier((int32_t) (end - begin), &_unopenedFiles);
	[self _onFinishedThread];
}

- (void)_processPath:(NSString*)path	// threaded
{
	NSString* errStr = nil;
	NSError* error = nil;

	const char* op = "reading";
	NSData* data = [NSData dataWithContentsOfFile:path options:0 error:&error];
	if (data)
	{
		op = "decoding";
		Decode* decoded = [[Decode alloc] initWithData:data];
		if (decoded.text)
		{
			NSMutableString* text = decoded.text;
			
			NSRange range = NSMakeRange(0, text.length);
			NSUInteger numMatches = [_regex replaceMatchesInString:text options:0 range:range withTemplate:_template];
			
			if (numMatches > 0)
			{
				OSAtomicAdd32Barrier((int32_t) numMatches, &_unopenedMatches);
				
				op = "writing";
				if (![text writeToFile:path atomically:YES encoding:decoded.encoding error:&error])
					errStr = [error localizedFailureReason];
			}
		}
		else
			errStr = decoded.error;
	}
	else
	{
		errStr = [error localizedFailureReason];
	}
	
	if (errStr)
	{
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_async(main,
		   ^{
			   NSString* mesg = [NSString stringWithFormat:@"Error %s '%@': %@", op, path, errStr];
			   [TranscriptController writeError:mesg];
		   });
	}
}

- (void)_onFinishedThread		// threaded
{
	ASSERT(_numThreads > 0);
	OSAtomicDecrement32Barrier(&_numThreads);
	
	if (_numThreads == 0)
	{
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_async(main,
		   ^{
			   NSUInteger numFiles = _openFiles + (NSUInteger) _unopenedFiles;
			   NSUInteger numMatches = _openMatches + (NSUInteger) _unopenedMatches;
			   NSString* mesg = [NSString stringWithFormat:@"Replaced %lu matches within %lu files.", numMatches, numFiles];
			   [TranscriptController writeCommand:mesg];
		   });
	}
}

@end
