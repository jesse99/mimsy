#import "Settings.h"

#import "AppDelegate.h"
#import "DirectoryController.h"
#import "LocalSettings.h"
#import "Logger.h"

@implementation Settings

+ (bool)boolValue:(NSString*)name missing:(bool)value
{
	NSString* result = [Settings stringValue:name missing:nil];
	
	if (result)
		return [result compare:@"true"] == NSOrderedSame;
	else
		return value;
}

+ (NSString*)stringValue:(NSString*)name missing:(NSString*)value
{
	DirectoryController* controller = [DirectoryController getCurrentController];
	NSString* result = controller != nil ? [controller.settings findKey:name] : nil;
	
	if (!result)
	{
		AppDelegate* delegate = [NSApp delegate];
		result = [delegate.settings findKey:name];
	}

	if (!result)
	{
		result = value;
	}
	
	return result;
}

+ (NSArray*)stringValues:(NSString*)name
{
	NSMutableArray* result = [NSMutableArray new];
	
	AppDelegate* delegate = [NSApp delegate];
	[result addObjectsFromArray:[delegate.settings findAllKeys:name]];
	
	DirectoryController* controller = [DirectoryController getCurrentController];
	if (controller)
		[result addObjectsFromArray:[controller.settings findAllKeys:name]];
	
	return result;
}

@end
