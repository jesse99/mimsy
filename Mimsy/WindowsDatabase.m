#import "WindowsDatabase.h"

#import "Assert.h"
#import "Database.h"
#import "Paths.h"

@implementation WindowsDatabase
{
	Database* _db;
}

static WindowsDatabase* _instance;

__attribute__((destructor))
static void destroy()
{
	_instance = nil;
}

+ (void)setup
{
	ASSERT(_instance == nil);
		
	_instance = [WindowsDatabase new];
}

- (id)init
{
	NSError* error = nil;
	if (Paths.caches)
	{
		NSString* path = [Paths.caches stringByAppendingPathComponent:@"Windows.db"];
		self->_db = [[Database alloc] initWithPath:path error:&error];
		if (error)
			goto err;
		
		[self->_db update:
@"			CREATE TABLE IF NOT EXISTS Windows("
"				path TEXT NOT NULL PRIMARY KEY"
"					CONSTRAINT absolute_path CHECK(substr(path, 1, 1) = '/'),"
"				length INTEGER NOT NULL"
"					CONSTRAINT non_negative_length CHECK(length >= 0),"
"				frame TEXT NOT NULL"
"					CONSTRAINT no_empty_frame CHECK(length(frame) > 0),"
"				scrollers TEXT NOT NULL"
"					CONSTRAINT no_empty_scrollers CHECK(length(scrollers) > 0),"
"				selection TEXT NOT NULL"
"					CONSTRAINT no_empty_selection CHECK(length(selection) > 0),"
"				word_wrap INTEGER NOT NULL"
"					CONSTRAINT valid_wrap CHECK(word_wrap = 0 || word_wrap = 1)"
"			)"
			error:&error];
		if (error)
			goto err;
	}
	return self;
	
err:
	LOG_ERROR("Mimsy", "Couldn't create database at '%s': %s", STR(Paths.caches), STR([error localizedFailureReason]));
	self->_db = nil;
	return self;
}

+ (NSRect) getFrame:(NSString*)path
{
	NSRect result = NSZeroRect;
	
	NSError* error = nil;
	if (_instance && _instance->_db)
	{
		NSArray* rows = [_instance->_db queryRows:[NSString stringWithFormat:
@"			SELECT frame"
"				FROM Windows"
"			WHERE path = '%@'", [path stringByReplacingOccurrencesOfString:@"'" withString:@"''"]]
			error:&error];
		if (error)
			goto err;
		
		if (rows.count > 0)		// no rows will happen if this is the first time we tried to open the document
		{
			NSArray* row = rows[0];
			result = NSRectFromString(row[0]);
		}
	}
	
	return result;
	
err:
	LOG_ERROR("Mimsy", "Query window frame failed: %s", STR([error localizedFailureReason]));
	return NSZeroRect;
}

+ (bool) getInfo:(struct WindowInfo*)info forPath:(NSString*)path
{	
	NSError* error = nil;
	if (_instance && _instance->_db)
	{
		NSArray* rows = [_instance->_db queryRows:[NSString stringWithFormat:
@"			SELECT length, scrollers, selection, word_wrap"
"				FROM Windows"
"			WHERE path = '%@'", [path stringByReplacingOccurrencesOfString:@"'" withString:@"''"]]
			error:&error];
		if (error)
			goto err;
		
		if (rows.count > 0)		// no rows will happen if this is the first time we tried to open the document
		{
			NSArray* row = rows[0];
			
			info->length = [row[0] integerValue];
			info->origin = NSPointFromString(row[1]);
			info->selection = NSRangeFromString(row[2]);
			info->wordWrap = [row[3] isEqualToString:@"1"];
			return true;
		}
	}
	
	return false;
	
err:
	LOG_ERROR("Mimsy", "Query window info failed: %s", STR([error localizedFailureReason]));
	return false;
}

+ (void) saveInfo:(const struct WindowInfo*)info frame:(NSRect)frame forPath:(NSString*)path
{
	NSError* error = nil;
	if (_instance && _instance->_db)
	{
		[_instance->_db update:[NSString stringWithFormat:
@"			INSERT OR REPLACE INTO Windows VALUES ('%@', '%@', '%@', '%@', '%@', %@)",
				[path stringByReplacingOccurrencesOfString:@"'" withString:@"''"],
				[NSString stringWithFormat:@"%ld", info->length],
				NSStringFromRect(frame),
				NSStringFromPoint(info->origin),
				NSStringFromRange(info->selection),
				info->wordWrap ? @"1" : @"0"]
			error:&error];
		if (error)
			goto err;
	}
		
	return;
	
err:
	LOG_ERROR("Mimsy", "Saving window info failed: %s", STR([error localizedFailureReason]));
}

@end
