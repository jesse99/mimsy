#import "TimeMachine.h"

#import "AppDelegate.h"
#import "Assert.h"
#import "StringCategory.h"
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
		_title = [NSString stringWithFormat:@"Open From %@", _timeStr];
	}
	else
	{
		_title = [NSString stringWithFormat:@"Open From ? seconds ago"];
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
		NSArray* oldFiles = [TimeMachine _tryFindOldFiles];
		if (oldFiles && oldFiles.count > 0)
		{
			NSMenu* tmMenu = [[NSMenu alloc] initWithTitle:@"Time Machine"];
			NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"Time Machine" action:NULL keyEquivalent:@""];
			[item setSubmenu:tmMenu];
			[menu addItem:item];

			for (OldFile* file in oldFiles)
			{
				[TimeMachine _appendFile:file toMenu:tmMenu];
			}
		}
		else if (!oldFiles)
		{
			// _findOldFiles is normally very fast (under 100 ms on a 2009 mac). However
			// snapshots are often stored on external drives. And if those drives are
			// asleep it can take seconds for them to spin back up. That's way too long
			// to wait while we are building a context menu so we'll punt on Time Machine
			// if it's taking too long.
			//
			// The other option is to do as Continuum did and add a menu item to open the
			// latest snapshot. And then in the snapshot's context menu we could add all
			// the other snapshots. This avoids spinning up the Time Machine volume
			// unnecessarily but it would also make the Time Machine functionality even
			// less discoverable than it is now.
			NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"Spinning up Time Machine" action:NULL keyEquivalent:@""];
			[item setEnabled:FALSE];
			[menu addItem:item];
		}
	}
}

+(NSArray*)_tryFindOldFiles
{
	__block NSCondition* condition = [NSCondition new];
	__block NSMutableArray* oldFiles = nil;
	
	// Grab the lock first thing so that the main thread can block in waitUntilDate
	// before the async code acquires the lock.
	[condition lock];

	dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
	dispatch_async(concurrent,
	   ^{
		   [condition lock];
		   
		   oldFiles = [TimeMachine _findOldFiles];
		   [TimeMachine removeDupes:oldFiles];
		   [TimeMachine _sortOldFiles:oldFiles];
		   
		   [condition signal];
		   [condition unlock];
	   });
	
	NSDate* date = [NSDate dateWithTimeIntervalSinceNow:0.25];
	bool completed = [condition waitUntilDate:date];
	[condition unlock];
	
	return completed ? oldFiles : nil;
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

+ (void)_appendFile:(OldFile*)file toMenu:(NSMenu*)menu
{
	NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:file.title action:@selector(openTimeMachine:) keyEquivalent:@""];
	
	[item setRepresentedObject:file.path];
	
	TextController* controller = [TextController frontmost];
	if ([controller.path compare:file.path] == 0)
		[item setState:NSOnState];
		 
	[menu addItem:item];
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
		LOG_ERROR("Mimsy", "error finding old time machine files: %s", STR(reason));
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
		LOG_ERROR("Mimsy", "%s", STR(mesg));
	}
	
	_lookedForTimeMachineDir = true;
}

@end
