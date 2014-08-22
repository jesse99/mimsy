#import "ReplaceInFiles.h"

#import "Assert.h"
#import "FindInFilesController.h"
#import "Logger.h"
#import "TextController.h"
#import "TranscriptController.h"

@implementation ReplaceInFiles
{
	FindInFilesController* _findController;
	NSString* _template;
	NSDictionary* _openFiles;	// path => TextController

	int32_t _numFiles;
	int32_t _numMatches;
	int32_t _numThreads;
}

- (id)init:(FindInFilesController*)controller path:(NSString*)path template:(NSString*)template
{
	self = [super init:controller path:path];
	
	if (self)
	{
		_findController = controller;
		_template = template;
	}
	
	return self;
}

- (void)replaceAll
{
	ASSERT(_numMatches == 0);		// these objects should be created from scratch for every search
	
	LOG("Find:Verbose", "Replace in files for '%s' and '%s'", STR(_findController.findText), STR(_template));
	[self _processRoot];
}

- (void)_step1ProcessOpenFiles
{
	_numThreads = 1;
	
	_openFiles = [self _findMatchingOpenFiles];
	if ([self.root compare:@"Open Windows"] != NSOrderedSame)
	{
		++_numThreads;
		[self _step2FindPaths];
	}
	[self _processOpenfiles];
}

- (NSDictionary*)_findMatchingOpenFiles
{
	NSMutableDictionary* openFiles = [NSMutableDictionary new];
	
	[TextController enumerate:
		^(TextController *controller)
		{
			if (controller.path)
			{
				NSString* fileName = [controller.path lastPathComponent];
				if ([self.includeGlobs matchName:fileName])
					[openFiles setValue:controller forKey:controller.path];
			}
		}];
	
	return openFiles;
}

// Kind of sucks to process all the open files in the main thread but it's tricky
// to handle by processing the files on disk, especially if the user is also
// editing the files. And also doing it in the main thread allows us to support
// undo within the open files.
- (void)_processOpenfiles
{
	for (NSString* path in _openFiles)
	{
		NSUInteger numMatches = replaceAll(_findController, _openFiles[path], self.regex, _template);
		if (numMatches > 0)
		{
			OSAtomicIncrement32(&_numFiles);
			OSAtomicAdd32Barrier((int32_t) numMatches, &_numMatches);
		}
	}
	
	if (--_numThreads == 0)
		[self _finishedReplacing];
}

- (bool)_processPath:(NSString*) path withContents:(NSMutableString*)contents	// threaded
{
	bool edited = false;
	
	if (!_openFiles[path])
	{
		if ([self.searchWithin compare:@"everything"] == NSOrderedSame)
		{
			NSRange range = NSMakeRange(0, contents.length);
			NSUInteger numMatches = [self.regex replaceMatchesInString:contents options:0 range:range withTemplate:_template];

			if (numMatches > 0)
			{
				OSAtomicIncrement32(&_numFiles);
				OSAtomicAdd32Barrier((int32_t) numMatches, &_numMatches);
				edited = true;
			}
		}
		else
		{
			edited = [super _processPath:path withContents:contents];
		}
	}
	
	return edited;
}

// TODO: Might be better to display a window with a progress bar. Could set the title like
// find in files does.
- (bool)_processMatches:(NSArray*)matches forPath:(NSString*)path withContents:(NSMutableString*)contents	// threaded
{
	UNUSED(path);
	bool edited = false;
	
	if (matches.count > 0)
	{
		for (NSUInteger i = matches.count - 1; i < matches.count; --i)
		{
			NSTextCheckingResult* match = matches[i];
			NSString* replacement = [self.regex replacementStringForResult:match inString:contents offset:0 template:_template];
			[contents replaceCharactersInRange:match.range withString:replacement];
		};
		
		OSAtomicIncrement32(&_numFiles);
		OSAtomicAdd32Barrier((int32_t) matches.count, &_numMatches);
		edited = true;
	}
	
	return edited;
}

- (bool)_aborted	// threaded
{
	return false;
}

- (void)_onFinish	// threaded
{
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_async(main,
	   ^{
		   if (--_numThreads == 0)
			   [self _finishedReplacing];
	   });
}

- (void)_finishedReplacing
{
	// It might be kind of nice to throw up a results window showing the replacements.
	// But, I think, most of the time no one cares. So all that would mean is that
	// they would have to go through the hassle of closing the results window. Not a
	// huge deal, but those minor annoyances add up. And, of course, if someone does
	// want to to see the results they can just kick off a search for them.
	NSString* mesg;
	if (_numMatches > 0)
	{
		NSString* matchStr = _numMatches == 1 ? @"1 match" : [NSString stringWithFormat:@"%d matches", _numMatches];
		NSString* filesStr = _numFiles == 1 ? @"within 1 file" : [NSString stringWithFormat:@"within %d files", _numFiles];
		
		mesg = [NSString stringWithFormat:@"Replace '%@' replaced %@ %@.\n", _findController.findText, matchStr, filesStr];
	}
	else
	{
		mesg = [NSString stringWithFormat:@"Replace '%@' replaced nothing.\n", _findController.findText];
	}
	
	[TranscriptController writeInfo:mesg];
}

@end
