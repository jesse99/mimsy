#import "DatabaseTests.h"
#import "Database.h"
#import "Utils.h"

@implementation DatabaseTests

- (void)testBasics
{
	NSString* path = [Utils pathForTemporaryFileWithPrefix:@"test-db"];
	
	NSError* error = nil;
	Database* db = [[Database alloc] initWithPath:path error:&error];
	STAssertNil(error, nil);
	
	if (error == nil)
	{
		[db update:@"CREATE TABLE People(id INTEGER PRIMARY KEY, first_name, last_name, city)" error:&error];
		STAssertNil(error, nil);
	}
	
	if (error == nil)
	{
		[db update:@"INSERT INTO People VALUES (1, 'joe', 'bob', 'houston')" error:&error];
		STAssertNil(error, nil);
	}
	
	if (error == nil)
	{
		[db update:@"INSERT INTO People VALUES (2, 'fred', 'hansen', 'atlanta')" error:&error];
		STAssertNil(error, nil);
	}
	
	if (error == nil)
	{
		[db update:@"INSERT INTO People VALUES (3, 'ted', 'bundy', 'houston')" error:&error];
		STAssertNil(error, nil);
	}
	
	NSArray* rows = nil;
	if (error == nil)
	{
		rows = [db queryRows:@"SELECT first_name, last_name FROM People WHERE city='houston'" error:&error];
		STAssertNil(error, nil);
	}
	
	if (error == nil)
	{
		STAssertEquals(rows.count, (NSUInteger) 2, nil);
		
		NSArray* row0 = rows[0];
		STAssertEquals(row0.count, (NSUInteger) 2, nil);
		STAssertEqualObjects(row0[0], @"joe", nil);
		STAssertEqualObjects(row0[1], @"bob", nil);
		
		NSArray* row1 = rows[1];
		STAssertEquals(row1.count, (NSUInteger) 2, nil);
		STAssertEqualObjects(row1[0], @"ted", nil);
		STAssertEqualObjects(row1[1], @"bundy", nil);
	}
}

@end
