#import "BaseInFiles.h"

#import "AppSettings.h"
#import "Assert.h"
#import "Decode.h"
#import "FindInFilesController.h"
#import "Language.h"
#import "Languages.h"
#import "Logger.h"
#import "RangeVector.h"
#import "RegexStyler.h"
#import "StringCategory.h"
#import "StyleRuns.h"
#import "TranscriptController.h"

@implementation BaseInFiles
{
	Glob* _excludeGlobs;
	Glob* _excludeAllGlobs;
}

- (id)init:(FindInFilesController*)controller path:(NSString*)path
{
	self = [super init];
	
	if (self)
	{
		_root = path;
		_regex = [controller _getRegex];	// note that NSRegularExpression is documented to be thread safe
		_searchWithin = controller.searchWithinComboBox.stringValue;
		
		NSArray* globs = [controller.includedGlobsComboBox.stringValue splitByString:@" "];
		_includeGlobs = [[Glob alloc] initWithGlobs:globs];
		
		globs = [controller.excludedGlobsComboBox.stringValue splitByString:@" "];
		_excludeGlobs = [[Glob alloc] initWithGlobs:globs];
		
		globs = [[AppSettings stringValue:@"FindAllAlwaysExclude" missing:@""] splitByString:@" "];
		_excludeAllGlobs = [[Glob alloc] initWithGlobs:globs];
	}
	
	return self;
}

- (void)_processRoot
{
	LOG_DEBUG("Find", "regex = %s", STR(_regex));
	[self _step1ProcessOpenFiles];
}

- (void)_step1ProcessOpenFiles
{
	ASSERT(false);
}

- (void)_step2FindPaths			// threaded
{
	NSMutableArray* paths = [NSMutableArray new];

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
							[dirPaths addObject:path];
						else if ([_includeGlobs matchName:item])
						{
							[paths addObject:path];
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
	
	_numFilesLeft = (int) paths.count;
	if (paths.count > 0)
		[self _step3QueuePaths:paths];
	else
		[self _onFinish];
}

- (void)_step3QueuePaths:(NSMutableArray*)paths		// sometimes threaded
{
	ASSERT(paths.count > 0);
	NSUInteger middle = paths.count/2;
	
	// We process the files using two threads so one can be reading from the hard
	// drive while the other is processing its file.
	dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(concurrent,
	   ^{
		   [self _step4ProcessPaths:paths begin:0 end:middle];
	   });
	dispatch_async(concurrent,
	   ^{
		   [self _step4ProcessPaths:paths begin:middle end:paths.count];
	   });
}

- (void)_step4ProcessPaths:(NSArray*)paths begin:(NSUInteger)begin end:(NSUInteger)end	// threaded
{
	for (NSUInteger i = begin; i < end && !self._aborted; ++i)
	{
		NSString* path = paths[i];
		NSString* errStr = nil;
		const char* op = "reading";
		
		NSError* error = nil;
		OSAtomicDecrement32Barrier(&_numFilesLeft);
		NSData* data = [NSData dataWithContentsOfFile:path options:0 error:&error];
		if (data)
		{
			op = "decoding";
			Decode* decoded = [[Decode alloc] initWithData:data];
			if (decoded.text)
			{
				bool edited = [self _processPath:path withContents:decoded.text];
				if (edited)
				{
					op = "writing";
					if (![decoded.text writeToFile:path atomically:YES encoding:decoded.encoding error:&error])
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
	
	if (_numFilesLeft == 0)
		[self _onFinish];
}

- (bool)_processPath:(NSString*) path withContents:(NSMutableString*)contents	// threaded
{
	NSMutableArray* matches = [NSMutableArray new];
	
	struct RangeVector* ranges = [self _findRangesForStyle:_searchWithin path:path contents:contents];

	NSRange range = NSMakeRange(0, contents.length);
	[_regex enumerateMatchesInString:contents options:0 range:range usingBlock:
		 ^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop)
		 {
			 UNUSED(flags, stop);
			 
			 if (match && [self _shouldProcessRange:match.range inRanges:ranges])
				 [matches addObject:match];
		 }];
	
	if (ranges)
	{
		freeRangeVector(ranges);
		free(ranges);
	}
	
	bool edited = [self _processMatches:matches forPath:path withContents:contents];
	
	return edited;
}

- (struct RangeVector*)_findRangesForStyle:(NSString*)styleName path:(NSString*)path contents:(NSString*)contents
{
	__block struct RangeVector* ranges = NULL;
	
	if ([_searchWithin compare:@"everything"] != NSOrderedSame)
	{
		ranges = malloc(sizeof(struct RangeVector));
		*ranges = newRangeVector();
		
		Language* language = [Languages findWithFileName:path.lastPathComponent contents:contents];
		if (language && language.styler)
		{
			StyleRuns* runs = [language.styler computeStyles:contents editCount:0];
			NSUInteger styleIndex = [runs nameToIndex:styleName];
			if (styleIndex != NSNotFound)
			{
				[runs processIndexes:
					 ^(NSUInteger elementIndex, NSRange range, bool *stop)
					 {
						 UNUSED(stop);
						 if (elementIndex == styleIndex)
							 pushRangeVector(ranges, range);
					 }];
			}
			
			sortRangeVector(ranges);
			for (NSUInteger i = 0; i < ranges->count; ++i)
			{
				LOG_INFO("Mimsy", "   range = %lu, %lu", ranges->data[i].location, ranges->data[i].length);
			}
		}
	}
	
	return ranges;
}

- (bool)_shouldProcessRange:(NSRange)range inRanges:(struct RangeVector*)ranges
{
	if (!ranges)
		return true;
	
	NSRange outerRange = subsetRangeVector(ranges, range);
	return outerRange.location != NSNotFound;
}

// subclasses need to implement these
- (bool)_processMatches:(NSArray*)matches forPath:(NSString*)path withContents:(NSMutableString*)contents	// threaded
{
	UNUSED(matches, path, contents);
	ASSERT(false);	
}

- (bool)_aborted	// threaded
{
	ASSERT(false);
}

- (void)_onFinish	// threaded
{
	ASSERT(false);
}

@end
