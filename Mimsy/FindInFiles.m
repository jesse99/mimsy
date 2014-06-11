#import "FindInFiles.h"

#import "AppDelegate.h"
#import "AppSettings.h"
#import "Assert.h"
#import "AttributedStringCategory.h"
#import "Decode.h"
#import "FindInFilesController.h"
#import "FindResultsController.h"
#import "Glob.h"
#import "Logger.h"
#import "Paths.h"
#import "PersistentRange.h"
#import "StringCategory.h"
#import "TextController.h"
#import "TextStyles.h"
#import "TranscriptController.h"

@implementation FindInFiles
{
	FindResultsController* _controller;
	int _filesLeft;
	int _matches;
	NSRegularExpression* _regex;
	
	NSString* _root;
	NSString* _findText;
	Glob* _includeGlobs;
	Glob* _excludeGlobs;
	Glob* _excludeAllGlobs;
	bool _reversePaths;
	
	NSDictionary* _pathAttrs;
	NSDictionary* _lineAttrs;
	NSDictionary* _disabledAttrs;
	NSDictionary* _matchAttrs;
}

- (id)init:(FindInFilesController*)controller path:(NSString*)path
{
	self = [super init];
	
	if (self)
	{
		_root = path;
		_regex = [controller _getRegex];	// note that NSRegularExpression is documented to be thread safe
		_findText = controller.findText;
		_controller = [[FindResultsController alloc] initWith:self];
		
		NSArray* globs = [controller.includedGlobsComboBox.stringValue splitByString:@" "];
		_includeGlobs = [[Glob alloc] initWithGlobs:globs];
		
		globs = [controller.excludedGlobsComboBox.stringValue splitByString:@" "];
		_excludeGlobs = [[Glob alloc] initWithGlobs:globs];
		
		globs = [[AppSettings stringValue:@"FindAllAlwaysExclude" missing:@""] splitByString:@" "];
		_excludeAllGlobs = [[Glob alloc] initWithGlobs:globs];
		
		_reversePaths = [AppSettings boolValue:@"ReversePaths" missing:true];
				
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
		[self _loadPrefs];
	}
	
	return self;
}

- (void)findAll
{
	[self step1];
}

// TODO: this may be a little slow, may want to batch things up
- (void)_updateResults:(NSString*)path withMatches:(NSArray*)matches
{
	UNUSED(path);
	ASSERT(_filesLeft > 0);
	
	if (_controller.window.isVisible)
	{
		NSString* title;
		if (--_filesLeft == 0)
			title = [NSString stringWithFormat:@"Find '%@' has %d matches", _findText, _matches];
		else if (_filesLeft == 1)
			title = [NSString stringWithFormat:@"Find '%@' with 1 file left", _findText];
		else
			title = [NSString stringWithFormat:@"Find '%@' with %d files left", _findText, _filesLeft];
		[_controller.window setTitle:title];
		
		if (matches.count > 0)
		{
			NSMutableAttributedString* str = [NSMutableAttributedString new];
			if (_reversePaths)
				[str.mutableString appendString:[path reversePath]];
			else
				[str.mutableString appendString:path];
			
			NSRange range = NSMakeRange(0, str.string.length);
			[str setAttributes:_pathAttrs range:range];
			[str addAttribute:@"FindPath" value:path range:range];
			
			_matches += matches.count;
			[_controller addPath:str matches:matches];
		}
	}
	else
	{
		[_controller releaseWindow];
		_controller = nil;
	}
}

- (NSString*)_findLineWithin:(NSString*)contents at:(NSRange)range newRange:(NSRange*)newRange
{
	NSUInteger begin = range.location;
	NSUInteger end = range.location + range.length;
	
	// Find the start of the line.
	while (begin > 0)
	{
		unichar ch = [contents characterAtIndex:begin-1];
		if (ch == '\r' || ch == '\n')
			break;
		--begin;
	}
	
	// Looks nicer if we skip leading whitespace.
	while (begin < range.location)
	{
		unichar ch = [contents characterAtIndex:begin];
		if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:ch])
			++begin;
		else
			break;
	}
	
	// Find the end of the line.
	while (end < contents.length)
	{
		unichar ch = [contents characterAtIndex:end];
		if (ch == '\r' || ch == '\n')
			break;
		++end;
	}
	
	*newRange = NSMakeRange(range.location - begin, range.length);
	
	return [contents substringWithRange:NSMakeRange(begin, end - begin)];
}

- (NSMutableAttributedString*)_getMatchStr:(NSString*)contents match:(NSTextCheckingResult*)match	// threaded
{
	NSRange newRange;
	NSString* line = [self _findLineWithin:contents at:match.range newRange:&newRange];
	
	NSMutableAttributedString* str = [NSMutableAttributedString new];
	[str.mutableString appendString:line];
	
	NSRange fullRange = NSMakeRange(0, line.length);
	[str setAttributes:_lineAttrs range:fullRange];
	[str setAttributes:_matchAttrs range:newRange];
	[str addAttribute:@"MatchedText" value:@"" range:newRange];
	
	return str;
}

- (void)_processPath:(NSString*)path withContents:(NSString*)contents	// threaded
{
	NSMutableArray* strings = [NSMutableArray new];
	NSMutableArray* matches = [NSMutableArray new];
	
	NSRange range = NSMakeRange(0, contents.length);
	[_regex enumerateMatchesInString:contents options:0 range:range usingBlock:
		 ^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop)
		 {
			 UNUSED(flags, stop);
			 
			 if (match)
			 {
				 NSMutableAttributedString* str = [self _getMatchStr:contents match:match];
				 [strings addObject:str];
				 [matches addObject:match];
			 }
		 }];
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_async(main,
	   ^{
		   for (NSUInteger i = 0; i < strings.count; ++i)
		   {
			   NSMutableAttributedString* str = strings[i];
			   NSTextCheckingResult* match = matches[i];
			   NSRange fullRange = NSMakeRange(0, str.string.length);
			   
			   PersistentRange* pr = [[PersistentRange alloc] init:path range:match.range block:
				  ^(PersistentRange* range)
				  {
					  if (range.range.location == NSNotFound)
					  {
						  [str setAttributes:_disabledAttrs range:fullRange];
						  [str addAttribute:@"FindRange" value:range range:fullRange];
						  [_controller.window display];
					  }
				  }];
			   [str addAttribute:@"FindRange" value:pr range:fullRange];
		   }
		   
		   [self _updateResults:path withMatches:strings];
	   });
}

// We do as much work as we can off the main thread so these functions chain
// into one another executing within different threads.
// 1) snapshot paths for all the open windows
- (void)step1
{
	NSMutableDictionary* allOpenPaths = [NSMutableDictionary new];	// path => contents
	
	NSString* title = [NSString stringWithFormat:@"Find '%@' gathering paths", _findText];
	[_controller.window setTitle:title];
	
	[TextController enumerate:
		 ^(TextController *controller)
		 {
			 if (controller.path)
			 {
				 NSString* contents = [controller.text copy];	// kind of sucks to do a copy, but it's not nearly as bad as reading into memory zillions of files
				 allOpenPaths[controller.path] = contents;
			 }
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
	NSMutableDictionary* openPaths = [NSMutableDictionary new];	// path => contents
	
	for (NSString* path in allOpenPaths)
	{
		NSString* fileName = [path lastPathComponent];
		if ([_includeGlobs matchName:fileName])
		{
			NSString* contents = [allOpenPaths valueForKey:path];
			if (contents)
				openPaths[path] = contents;
		}
	}
	
	_filesLeft = (int) openPaths.count;
	
	if (openPaths.count > 0)
		[self _step3aWithOpenPaths:openPaths];
}

// 2) get a list of paths to the files we need to process
// in the main thread and a worker thread
- (void)step2WithOpenPaths:(NSDictionary*)allOpenPaths	// threaded
{
	NSFileManager* fm = [NSFileManager new];
	NSMutableDictionary* openPaths = [NSMutableDictionary new];	// path => contents
	NSMutableArray* unopenedPaths = [NSMutableArray new];		// paths
	
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
								openPaths[path] = contents;
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
- (void)_step3aWithOpenPaths:(NSDictionary*)paths		// threaded
{
	for (NSString* path in paths)
	{
		if (!_controller)
			break;
		
		NSString* contents = [paths objectForKey:path];
		[self _processPath:path withContents:contents];
	}
}

// 3b) process files on disk
- (void)_step3bWithUnopenedPaths:(NSArray*)paths begin:(NSUInteger)begin end:(NSUInteger)end	// threaded
{
	NSString* errStr = nil;
	NSError* error = nil;
	for (NSUInteger i = begin; i < end && _controller; ++i)
	{
		NSString* path = paths[i];
		
		NSData* data = [NSData dataWithContentsOfFile:path options:0 error:&error];
		if (data)
		{
			Decode* decoded = [[Decode alloc] initWithData:data];
			if (decoded.text)
				[self _processPath:path withContents:decoded.text];
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
				   NSString* mesg = [NSString stringWithFormat:@"Error reading '%@': %@", path, errStr];
				   [TranscriptController writeError:mesg];
			   });
		}
	}
}

- (void)settingsChanged:(NSNotification*)notification
{
	(void) notification;
	
	[self _loadPrefs];
}

- (void)_loadPrefs
{
	NSString* dir = [Paths installedDir:@"settings"];
	NSString* path = [dir stringByAppendingPathComponent:@"find-results.rtf"];
	TextStyles* styles = [[TextStyles new] initWithPath:path expectBackColor:false];
	
	_pathAttrs     = [styles attributesForElement:@"pathstyle"];
	_lineAttrs     = [styles attributesForElement:@"linestyle"];
	_matchAttrs    = [styles attributesForElement:@"matchstyle"];
	_disabledAttrs = [styles attributesForElement:@"disabledstyle"];
	
	[_controller
		 resetPath:^NSAttributedString* (NSAttributedString* str)
			{return [self _resetPathAttributes:str];}
		 andMatchStyles:^NSAttributedString* (NSAttributedString* str)
			{return [self _resetMatchAttributes:str];
		 }];
}

- (NSAttributedString*)_resetPathAttributes:(NSAttributedString*)oldStr
{
	NSMutableAttributedString* newStr = [NSMutableAttributedString new];
	[newStr.mutableString appendString:oldStr.string];
	
	NSRange range = NSMakeRange(0, newStr.string.length);
	[newStr setAttributes:_pathAttrs range:range];
	[newStr copyAttributes:@[@"FindPath"] from:oldStr];
	
	return newStr;
}

- (NSAttributedString*)_resetMatchAttributes:(NSAttributedString*)oldStr
{
	NSMutableAttributedString* newStr = [NSMutableAttributedString new];
	[newStr.mutableString appendString:oldStr.string];	
	NSRange fullRange = NSMakeRange(0, newStr.string.length);
	
	PersistentRange* range = [oldStr attribute:@"FindRange" atIndex:0 effectiveRange:NULL];
	if (range.range.location == NSNotFound)
	{
		[newStr setAttributes:_disabledAttrs range:fullRange];
	}
	else
	{
		[newStr setAttributes:_lineAttrs range:fullRange];
		[oldStr enumerateAttribute:@"MatchedText" inRange:fullRange options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:
			 ^(id value, NSRange range, BOOL *stop)
			 {
				 UNUSED(value, stop);
				 
				 if (value)
				 {
					 [newStr setAttributes:_matchAttrs range:range];
					 [newStr addAttribute:@"MatchedText" value:@"" range:range];
				 }
			 }];
	}

	[newStr addAttribute:@"FindRange" value:range range:fullRange];
	
	return newStr;
}

@end
