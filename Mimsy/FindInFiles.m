#import "FindInFiles.h"

#import "AppDelegate.h"
#import "AppSettings.h"
#import "Assert.h"
#import "FindInFilesController.h"
#import "FindResultsController.h"
#import "Glob.h"
#import "Logger.h"
#import "StringCategory.h"
#import "TextController.h"
#import "TranscriptController.h"

@implementation FindInFiles
{
	FindResultsController* _controller;
	int _filesLeft;
	int _matches;
	
	NSString* _root;
	NSString* _findText;
	Glob* _includeGlobs;
	Glob* _excludeGlobs;
	Glob* _excludeAllGlobs;
}

- (id)init:(FindInFilesController*)controller path:(NSString*)path
{
	self = [super init];
	
	if (self)
	{
		_root = path;
		_findText = controller.findText;
		_controller = [[FindResultsController alloc] initWith:self];
		
		NSArray* globs = [controller.includedGlobsComboBox.stringValue splitByString:@" "];
		_includeGlobs = [[Glob alloc] initWithGlobs:globs];
		
		globs = [controller.excludedGlobsComboBox.stringValue splitByString:@" "];
		_excludeGlobs = [[Glob alloc] initWithGlobs:globs];

		globs = [[AppSettings stringValue:@"FindAllAlwaysExclude" missing:@""] splitByString:@" "];
		_excludeAllGlobs = [[Glob alloc] initWithGlobs:globs];
	}
	
	return self;
}

- (void)findAll
{
	[self step1];
}

// TODO: this may be a little slow, may want to batch things up
- (void)_updateResults:(NSString*)path
{
	UNUSED(path);

	ASSERT(_filesLeft > 0);

	// TODO:
	// set _controller to nil if the window isn't visible
	// also need to call some sort of okToClose method
	NSString* title;
	if (--_filesLeft == 0)
		title = [NSString stringWithFormat:@"Find '%@' has %d matches", _findText, _matches];
	else if (_filesLeft == 1)
		title = [NSString stringWithFormat:@"Find '%@' with 1 file left", _findText];
	else
		title = [NSString stringWithFormat:@"Find '%@' with %d files left", _findText, _filesLeft];
	[_controller.window setTitle:title];
	LOG_INFO("Mimsy", "%s", STR(title));
}

- (void)_processPath:(NSString*)path withContents:(NSString*)contents	// threaded
{
	LOG_INFO("Mimsy", "find all in %s: %s", STR(path.lastPathComponent), STR([contents substringToIndex:MIN(32, contents.length)]));
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_async(main,
	   ^{
		   [self _updateResults:path];
	   });
}

// We do as much work as we can off the main thread so these functions chain
// into one another executing within different threads.
// 1) snapshot paths for all the open windows
- (void)step1
{
	NSMutableDictionary* allOpenPaths = [NSMutableDictionary new];
	
	NSString* title = [NSString stringWithFormat:@"Find '%@' gathering paths", _findText];
	[_controller.window setTitle:title];

	[TextController enumerate:
		^(TextController *controller)
		{
			if (controller.path)
			{
				NSString* contents = [controller.text copy];	// kind of sucks to do a copy, but it's not nearly as bad as reading into memory zillions of files
				[allOpenPaths setValue:contents forKey:controller.path];
			}
		}];
	
	dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(concurrent,
	   ^{
		   [self step2WithOpenPaths:allOpenPaths];
	   });
}

// 2) get a list of paths to the files we need to process
// in the main thread and a worker thread
- (void)step2WithOpenPaths:(NSDictionary*)allOpenPaths			// threaded
{
	NSFileManager* fm = [NSFileManager new];
	NSMutableDictionary* openPaths = [NSMutableDictionary new];
	NSMutableArray* unopenedPaths = [NSMutableArray new];
	
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
							NSString* contents = [allOpenPaths valueForKey:path];
							if (contents)
								[openPaths setValue:contents forKey:path];
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
	
	_filesLeft = (int) (openPaths.count + unopenedPaths.count);
	
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
		[self _step3aWithOpenPaths:openPaths];
}

// 3a) process the windows which were open
- (void)_step3aWithOpenPaths:(NSDictionary*)paths			// threaded
{
	for (NSString* path in paths)
	{
		if (!_controller)
			break;
		
		NSString* contents = [paths objectForKey:path];
		[self _processPath:path withContents:contents];
	}
}

// TODO:
// read in the file
// do the search
// maybe when finder checks for closed window it can call an allDone method on the controller
// make sure that we don't crash when window closes (maybe sleep in enumerate)
// pop up a window
// make sure the finder bails if the window is closed
// search the unopened paths in a thread
// periodically update the window (and the title with progress)
// update the window if the user edits an opened window
//
// 3b) process files on disk
- (void)_step3bWithUnopenedPaths:(NSArray*)paths begin:(NSUInteger)begin end:(NSUInteger)end	// threaded
{
	for (NSUInteger i = begin; i < end && _controller; ++i)
	{
		NSString* path = paths[i];
		NSString* contents = @"...";
		[self _processPath:path withContents:contents];
	}
}

@end
