#import "FindInFiles.h"

#import "AppSettings.h"
#import "ArrayCategory.h"
#import "Assert.h"
#import "AttributedStringCategory.h"
#import "FindInFilesController.h"
#import "FindResultsController.h"
#import "Logger.h"
#import "Paths.h"
#import "PersistentRange.h"
#import "StringCategory.h"
#import "TextController.h"
#import "TextStyles.h"
#import "TranscriptController.h"

@implementation FindInFiles
{
	FindResultsController* _resultsController;
	NSUInteger _numFiles;
	NSUInteger _numMatches;
	
	NSString* _findText;
	bool _reversePaths;
	
	NSDictionary* _pathAttrs;
	NSDictionary* _lineAttrs;
	NSDictionary* _disabledAttrs;
	NSDictionary* _matchAttrs;
}

- (id)init:(FindInFilesController*)controller path:(NSString*)path
{
	self = [super init:controller path:path];
	
	if (self)
	{
		_findText = controller.findText;
		_resultsController = [[FindResultsController alloc] initWith:self];
		
		_reversePaths = [AppSettings boolValue:@"ReversePaths" missing:true];
				
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
		[self _loadPrefs];
	}
	
	return self;
}

- (void)findAll
{
	ASSERT(_numMatches == 0);		// these objects should be created from scratch for every search

	LOG_DEBUG("Find", "Find in files for '%s'", STR(_findText));
	NSString* title = [NSString stringWithFormat:@"Find '%@' gathering paths", _findText];
	[_resultsController.window setTitle:title];
	
	[self _processRoot];
}

// This might be a bit slower than processing the documents in-memory but it's
// much simpler to always process files on disk and allows us to do all the work
// off the main thread so we avoid locking up the UI in the event that the user
// is dealing with very large files.
- (void)_step1ProcessOpenFiles
{
	__block NSMutableArray* openPaths = [NSMutableArray new];
	__block int numPendingSaves = 0;
	
	void (^nextStep)() = ^()
	{
		dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_async(concurrent, ^
		   {
			   if ([self.root compare:@"Open Windows"] == NSOrderedSame)
			   {
				   self.numFilesLeft = (int) openPaths.count;
				   if (openPaths.count > 0)
					   [self _step3QueuePaths:openPaths];
			   }
			   else
			   {
				   [self _step2FindPaths];
			   }
		   });
	};
	
	[TextController enumerate:
		 ^(TextController *controller)
		 {
			 if (controller.path)
			 {
				 NSString* fileName = [controller.path lastPathComponent];
				 if ([self.includeGlobs matchName:fileName])
				 {
					 [openPaths addObject:controller.path];
					 
					 NSDocument* doc = controller.document;
					 if (doc.hasUnautosavedChanges)
					 {
						 ++numPendingSaves;
						 
						 BOOL canCancel = [doc autosavingIsImplicitlyCancellable];
						 [doc autosaveWithImplicitCancellability:canCancel completionHandler:
							  ^(NSError *error)	// note that this executes on the main thread
							  {
								  if (error)
								  {
									  NSString* reason = [error localizedFailureReason];
									  NSString* mesg = [NSString stringWithFormat:@"Failed to auto-save %@: %@", fileName, reason];
									  [TranscriptController writeError:mesg];
								  }
								  
								  if (--numPendingSaves == 0)
									  nextStep();
							  }];
					 }
				 }
			 }
		 }];
	
	// Handles the case where we didn't need to auto-save anything.
	if (numPendingSaves == 0)
		nextStep();
}

- (bool)_processMatches:(NSArray*)matches forPath:(NSString*)path withContents:(NSMutableString*)contents	// threaded
{	
	NSAttributedString* pathStr = [self _getPathString:path];
	NSArray* matchStrs = [matches map:
		  ^id (NSTextCheckingResult *match)
		  {
			  return [self _getMatchStr:contents match:match];
		  }];
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_async(main,
	   ^{
		   if (_resultsController.window.isVisible)
		   {
			   if (matches.count > 0)
			   {
				   LOG_DEBUG("Find", "Found %lu matches for %s", matches.count, STR(path.lastPathComponent));
				   ++_numFiles;
				   _numMatches += matches.count;
				   
				   [self _addPersistentAttribute:matchStrs matches:matches path:path];
				   [_resultsController addPath:pathStr matches:matchStrs];
			   }
			   else
			   {
				   LOG_DEBUG("Find", "Found 0 matches for %s", STR(path.lastPathComponent));
			   }

			   NSString* title = [self _getResultsWindowTitle];
			   [_resultsController.window setTitle:title];
		   }
		   else
		   {
			   [_resultsController releaseWindow];
			   _resultsController = nil;
		   }
	   });
	
	return false;
}

- (NSString*)_getResultsWindowTitle
{
	NSString* title;

	if (self.numFilesLeft == 0)
	{
		if (_numMatches > 0)
		{
			NSString* matchStr = _numMatches == 1 ? @"1 match" : [NSString stringWithFormat:@"%lu matches", _numMatches];
			NSString* filesStr = _numFiles == 1 ? @"within 1 file" : [NSString stringWithFormat:@"within %lu files", _numFiles];
			
			title = [NSString stringWithFormat:@"Find '%@' had %@ %@", _findText, matchStr, filesStr];
		}
		else
		{
			title = [NSString stringWithFormat:@"Find '%@' had no matches", _findText];
		}
	}
	else if (self.numFilesLeft == 1)
	{
		title = [NSString stringWithFormat:@"Find '%@' with 1 file left", _findText];
	}
	else
	{
		title = [NSString stringWithFormat:@"Find '%@' with %d files left", _findText, self.numFilesLeft];
	}
	
	return title;
}

- (bool)_aborted	// threaded
{
	return !_resultsController;
}

- (void)_onFinish	// threaded
{
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_async(main,
	   ^{
		   LOG_DEBUG("Find", "Finished find");
		   if (_resultsController.window.isVisible)
		   {
			   NSString* title = [self _getResultsWindowTitle];
			   [_resultsController.window setTitle:title];
		   }
		   else
		   {
			   [_resultsController releaseWindow];
			   _resultsController = nil;
		   }
	   });
}

- (NSAttributedString*)_getPathString:(NSString*)path	// threaded
{
	NSMutableAttributedString* str = [NSMutableAttributedString new];
	if (_reversePaths)
		[str.mutableString appendString:[path reversePath]];
	else
		[str.mutableString appendString:path];
	
	NSRange range = NSMakeRange(0, str.string.length);
	[str setAttributes:_pathAttrs range:range];
	[str addAttribute:@"FindPath" value:path range:range];

	return str;
}

- (NSAttributedString*)_getMatchStr:(NSString*)contents match:(NSTextCheckingResult*)match	// threaded
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

- (NSString*)_findLineWithin:(NSString*)contents at:(NSRange)range newRange:(NSRange*)newRange	// threaded
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

- (void)_addPersistentAttribute:(NSArray*)matchStrs matches:(NSArray*)matches path:(NSString*)path
{
	for (NSUInteger i = 0; i < matchStrs.count; ++i)
	{
		NSMutableAttributedString* str = matchStrs[i];
		NSTextCheckingResult* match = matches[i];
		NSRange fullRange = NSMakeRange(0, str.string.length);
		
		PersistentRange* pr = [[PersistentRange alloc] init:path range:match.range block:
			   ^(PersistentRange* range)
			   {
				   if (range.range.location == NSNotFound)
				   {
					   [str setAttributes:_disabledAttrs range:fullRange];
					   [str addAttribute:@"FindRange" value:range range:fullRange];
					   [_resultsController.window display];
				   }
			   }];
		[str addAttribute:@"FindRange" value:pr range:fullRange];
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
	
	[_resultsController
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
