#import "Database.h"

#import <sqlite3.h>
#import "Assert.h"

@implementation Database
{
	sqlite3* _database;
}

- (void)dealloc
{
	if (_database)
		(void) sqlite3_close(_database);
}

- (id)initWithPath:(NSString*)path error:(NSError**)error
{
	ASSERT(error != NULL);
	
	self = [super init];
	if (self)
	{
		int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX;
		int err = sqlite3_open_v2([path UTF8String], &_database, flags, NULL);
		if (err != SQLITE_OK)
		{
			NSString* mesg = [[NSString alloc] initWithFormat:@"Failed to open '%@' (%d).", path, err];
			NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
			*error = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
		}
		else if (_database == NULL)
		{
			NSString* mesg = [[NSString alloc] initWithFormat:@"Failed to open '%@'.", path];
			NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
			*error = [NSError errorWithDomain:@"mimsy" code:5 userInfo:dict];
		}
		else
		{
			(void) sqlite3_busy_timeout(_database, 5*1000);
			*error = nil;
		}
			
		self = *error == nil ? self : nil;
	}
	
	return self;
}

- (bool)update:(NSString*)command error:(NSError**)error
{
	ASSERT(error != NULL);
	
	char* errMesg = NULL;
	int err = sqlite3_exec(_database, [command UTF8String], NULL, NULL, &errMesg);
	if (err != SQLITE_OK)
	{
		NSString* underlying;
		if (errMesg)
			underlying = [NSString stringWithUTF8String:errMesg];
		else
			underlying = [NSString stringWithFormat:@"error %d", err];
		
		NSString* mesg = [NSString stringWithFormat:@"Failed to run '%@': %@.", command, underlying];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:6 userInfo:dict];
	}
	return *error == NULL;
}

static int queryCallback(void* context, int numCols, char** values, char** names)
{
	(void) names;
	
	NSMutableArray* rows = (__bridge NSMutableArray*) context;
	
	NSMutableArray* row = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)numCols];
	for (int i = 0; i < numCols; ++i)
	{
		[row addObject:[NSString stringWithUTF8String:values[i]]];
	}
	[rows addObject:row];
	
	return SQLITE_OK;
}

- (NSArray*)queryRows:(NSString*)command error:(NSError**)error
{
	ASSERT(error != NULL);
	
	NSMutableArray* rows = [[NSMutableArray alloc] initWithCapacity:16];
	
	char* errMesg = NULL;
	int err = sqlite3_exec(_database, [command UTF8String], queryCallback, (__bridge void*) rows, &errMesg);
	if (err != SQLITE_OK)
	{
		NSString* underlying;
		if (errMesg)
			underlying = [NSString stringWithUTF8String:errMesg];
		else
			underlying = [NSString stringWithFormat:@"error %d", err];
		
		NSString* mesg = [NSString stringWithFormat:@"Failed to run '%@': %@.", command, underlying];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:6 userInfo:dict];
	}
	
	return rows;
}

@end
