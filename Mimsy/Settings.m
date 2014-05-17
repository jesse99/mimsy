#import "Settings.h"

#import "AppDelegate.h"
#import "DirectoryController.h"
#import "Logger.h"

@implementation Settings

+ (bool)boolValue:(NSString*)name missing:(bool)value
{
	NSString* result = [[DirectoryController getCurrentController] findSetting:name];
	if (!result)
		result = [AppDelegate findSetting:name];
	
	if (result)
		return [result compare:@"true"] == NSOrderedSame;
	else
		return value;
}

+ (NSString*)stringValue:(NSString*)name missing:(NSString*)value
{
	NSString* result = [[DirectoryController getCurrentController] findSetting:name];
	if (!result)
		result = [AppDelegate findSetting:name];
	
	if (result)
		return result;
	else
		return value;
}

@end
