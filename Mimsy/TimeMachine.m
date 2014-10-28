#import "TimeMachine.h"

#import "AppDelegate.h"
#import "OpenFile.h"
#import "SelectNameController.h"
#import "TextController.h"
#import "TranscriptController.h"
#import "Utils.h"

static bool _lookedForTimeMachineDir;
static NSString* _timeMachineDir;

@interface OldFile : NSObject

- (id)initWithSnapshot:(NSString*)snapshotPath andPath:(NSString*)path;

@property (readonly) NSString* path;
@property (readonly) NSNumber* fileNum;
@property (readonly) NSString* title;
@property (readonly) double timeStamp;		// seconds from now
@property (readonly) NSString* timeStr;		// "1 hour 2 minutes ago"

@end

@implementation OldFile

static NSString* getTitleComponent(double* timestamp, double amount, NSString* units)
{
	int delta = (int) floor(*timestamp/amount);
	if (delta == 1)
	{
		*timestamp -= amount;
		return [NSString stringWithFormat:@"1 %@ ", units];
	}
	else
	{
		*timestamp -= delta*amount;
		return [NSString stringWithFormat:@"%d %@s ", delta, units];
	}
}

static NSString* _getTimeStr(double timestamp)
{
	const double minutes = 60.0;
	const double hours = 60*minutes;
	const double days = 24*hours;
	const double weeks = 7*days;
	const double months = 4*weeks;		// this isn't exactly right but doesn't need to be
	const double years = 12*months;
	
	NSString* title = @"";
	if (timestamp > years)
		title = [title stringByAppendingString:getTitleComponent(&timestamp, years, @"year")];
	if (timestamp > months)
		title = [title stringByAppendingString:getTitleComponent(&timestamp, months, @"month")];
	if (timestamp > days)
		title = [title stringByAppendingString:getTitleComponent(&timestamp, days, @"day")];
	if (timestamp > hours)
		title = [title stringByAppendingString:getTitleComponent(&timestamp, hours, @"hour")];
	if (timestamp > minutes)
		title = [title stringByAppendingString:getTitleComponent(&timestamp, minutes, @"minute")];

	title = [title stringByAppendingString:@"ago"];
	
	return title;
}

- (id)initWithSnapshot:(NSString*)snapshotPath andPath:(NSString*)path
{
	UNUSED(snapshotPath);
	
	_path = path;
	
	NSError* error = nil;
	NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
	if (attrs)
	{
		NSDate* fileTime = attrs[NSFileModificationDate];
		_fileNum = attrs[NSFileSystemFileNumber];
		_timeStamp = fabs([fileTime timeIntervalSinceNow]);
		_timeStr = _getTimeStr(_timeStamp);
		_title = [NSString stringWithFormat:@"From %@", _timeStr];
	}
	else
	{
		_title = [NSString stringWithFormat:@"From ? seconds ago"];
	}
	
	return self;
}

@end

@implementation TimeMachine

+(bool)isSnapshotFile:(NSString*)path
{
	if (!_lookedForTimeMachineDir)
		[TimeMachine _findTimeMachineDir];
	
	return _timeMachineDir && [path startsWith:_timeMachineDir];
}

+(NSString*)getSnapshotLabel:(NSString*)path
{
	NSString* label = @"? seconds";
	
	NSError* error = nil;
	NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
	if (attrs)
	{
		NSDate* fileTime = attrs[NSFileModificationDate];
		double timeStamp = fabs([fileTime timeIntervalSinceNow]);
		label = _getTimeStr(timeStamp);
	}
	
	return label;
}

+(void)appendContextMenu:(NSMenu*)menu;
{
	if (!_lookedForTimeMachineDir)
		[TimeMachine _findTimeMachineDir];
	
	if (_timeMachineDir)
	{
		// It'd be nicer to just add a submenu with all of the old files listed. However that
		// can be slow, especially if snapshots are on an external drive that needs to be spun
		// up. So we'll defer all of that until we know that the user really wants those files.
		TextController* controller = [TextController frontmost];
		if (controller && controller.path)
		{
			NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"Open Latest" action:@selector(openLatestInTimeMachine:) keyEquivalent:@""];
			[menu addItem:item];

			item = [[NSMenuItem alloc] initWithTitle:@"Open Time Machine…" action:@selector(openTimeMachine:) keyEquivalent:@""];
			[menu addItem:item];
		}
	}
}

+ (void)openLatest
{
	NSArray* oldFiles = [TimeMachine _tryFindOldFiles];
	if (oldFiles && oldFiles.count > 0)
	{
		OldFile* file = oldFiles[0];
		NSURL* url = [NSURL fileURLWithPath:file.path isDirectory:FALSE];

		AppDelegate* app = (AppDelegate*) [NSApp delegate];
		[app openWithMimsy:url];
	}
	else
	{
		NSBeep();
	}
}

+ (void)openFiles
{
	NSArray* oldFiles = [TimeMachine _tryFindOldFiles];
	if (oldFiles && oldFiles.count > 0)
	{
		TextController* tc = [TextController frontmost];
		NSString* title = [NSString stringWithFormat:@"%@ Files", tc.path.lastPathComponent];
		NSArray* titles = [oldFiles map:^id(OldFile* file) {return file.title;}];
		SelectNameController* controller = [[SelectNameController alloc] initWithTitle:title names:titles];
		(void) [NSApp runModalForWindow:controller.window];
		
		if (controller.selectedRows)
		{
			if ([OpenFile shouldOpenFiles:controller.selectedRows.count])
			{
				AppDelegate* app = (AppDelegate*) [NSApp delegate];
				[controller.selectedRows enumerateIndexesUsingBlock:
					^(NSUInteger index, BOOL* stop)
					 {
						 UNUSED(stop);
						 
						 OldFile* file = oldFiles[index];
						 NSURL* url = [NSURL fileURLWithPath:file.path isDirectory:FALSE];					 
						 [app openWithMimsy:url];
					 }];
			}
		}
	}
	else
	{
		NSBeep();
	}
}

+(NSArray*)_tryFindOldFiles
{
	NSMutableArray* oldFiles = [TimeMachine _findOldFiles];
   [TimeMachine removeDupes:oldFiles];
   [TimeMachine _sortOldFiles:oldFiles];
	
	return oldFiles;
}

+ (void)removeDupes:(NSMutableArray*)oldFiles
{
	for (NSUInteger i = 0; i < oldFiles.count; ++i)
	{
		OldFile* firstFile = oldFiles[i];
		
		NSUInteger j = i + 1;
		while (j < oldFiles.count)
		{
			OldFile* nextFile = oldFiles[j];
			if ([nextFile.fileNum compare:firstFile.fileNum] == 0)
				[oldFiles removeObjectAtIndex:j];
			else
				++j;
		}
	}
}

+ (void)_sortOldFiles:(NSMutableArray*)oldFiles
{
	[oldFiles sortUsingComparator:
		 ^NSComparisonResult(OldFile* lhs, OldFile* rhs)
		 {
			 if (lhs.timeStamp < rhs.timeStamp)
				 return NSOrderedAscending;				// backwards so newest are first
			 else if (lhs.timeStamp > rhs.timeStamp)
				 return NSOrderedDescending;
			 else
				 return NSOrderedSame;
		 }
	 ];
}

+ (void)_getOriginalPath:(NSString**)originalPath andVolume:(NSString**)volume fromController:(TextController*)controller
{
	if ([controller.path startsWith:_timeMachineDir])
	{
		NSArray* root = [_timeMachineDir pathComponents];
		
		// remove the time machine dir, e.g. /Volumes/Seagate/Backups.backupdb/Jesse Jones’s Mac Pro
		NSMutableArray* inner = [NSMutableArray arrayWithArray:[controller.path pathComponents]];
		[inner removeObjectsInRange:NSMakeRange(0, root.count)];
		
		// remove the snapshot dir, eg 2014-04-27-110800
		[inner removeObjectAtIndex:0];
		
		// save off the volume
		*volume = inner[0];
		[inner removeObjectAtIndex:0];

		// save off the originalPath
		*originalPath = [NSString pathWithComponents:inner];
	}
	else
	{
		NSError* error = nil;
		NSURL* url = [[NSURL alloc] initFileURLWithPath:controller.path isDirectory:FALSE];
		if ([url getResourceValue:volume forKey:NSURLVolumeNameKey error:&error] && volume)
		{
			*originalPath = controller.path;
		}
		else if (error)
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Error attempting to get the volume for the window: %@", reason];
			[TranscriptController writeError:mesg];
		}
	}
}

+ (NSMutableArray*)_findOldFiles
{
	NSMutableArray* oldFiles = nil;
	
	TextController* controller = [TextController frontmost];
	if (controller)
	{
		NSString* volume = nil;
		NSString* path = nil;
		[TimeMachine _getOriginalPath:&path andVolume:&volume fromController:controller];
		
		if (path)
			oldFiles = [TimeMachine _findOldFilesFor:path inVolume:volume];
	}
	
	// It's important to return a non-nil array so that we can distinguish timing out
	// from no files found.
	if (!oldFiles)
		oldFiles = [NSMutableArray new];
	
	return oldFiles;
}

// The directories look like this:
//		_timeMachineDir	/Volumes/Seagate/Backups.backupdb/Jesse Jones’s Mac Pro
//		path			/Users/jessejones/Source/mobjc/sample/AssemblyInfo.cs
//		volume			Macintosh HD
// Under _timeMachineDir we have a directory structure like:
//		2014-04-27-110800				(the last six digits are apparently random numbers)
//		2014-04-27-120915
//		2014-04-27-124723.inProgress
//		Latest -> 2014-04-27-120915
// And under those each volume that is backed up.
+ (NSMutableArray*)_findOldFilesFor:(NSString*)originalPath inVolume:(NSString*)volume
{	
	NSMutableArray* oldFiles = [NSMutableArray new];
	
	NSString* suffix = [volume stringByAppendingPathComponent:originalPath];
	
	NSError* error = nil;
	[Utils enumerateDir:_timeMachineDir glob:nil error:&error block:
		^(NSString* snapshotPath)
		{
			NSString* fileName = [snapshotPath lastPathComponent];
			if (![fileName startsWith:@".'"] && ![fileName contains:@"inProgess"] && ![fileName contains:@"Latest"])
			{
				NSString* path = [snapshotPath stringByAppendingPathComponent:suffix];
				if ([[NSFileManager defaultManager] fileExistsAtPath:path])
					[oldFiles addObject:[[OldFile alloc] initWithSnapshot:snapshotPath andPath:path]];
			}
		}
	];

	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		LOG("Error", "error finding old time machine files: %s", STR(reason));
	}
	
	return oldFiles;
}

+ (void)_findTimeMachineDir
{
	// It's be nicer to use something like NSSearchPathForDirectoriesInDomains but that
	// doesn't provide a way to get at the Time Machine directory. However tmutil should
	// be a safe way to find it.
	NSTask* task = [NSTask new];
	[task setLaunchPath:@"/usr/bin/tmutil"];
	[task setArguments:@[@"machinedirectory"]];
	[task setStandardOutput:[NSPipe new]];
	[task setStandardError:[NSPipe new]];
	
	NSString* stdout = nil;
	NSString* stderr = nil;
	NSError* err = [Utils run:task stdout:&stdout stderr:&stderr timeout:MainThreadTimeOut];
	
	if (!err)
	{
		_timeMachineDir = [stdout stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
	else
	{
		NSString* reason = [err localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Error running tmutil: %@\n", reason];
		LOG("Error", "%s", STR(mesg));
	}
	
	_lookedForTimeMachineDir = true;
}

@end
