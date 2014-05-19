#import "Settings.h"

#import "AppDelegate.h"
#import "DirectoryController.h"
#import "LocalSettings.h"
#import "Logger.h"
#import "TranscriptController.h"

@implementation Settings

+ (bool)boolValue:(NSString*)name missing:(bool)value
{
	NSString* str = [Settings stringValue:name missing:nil];
	
	if (str)
		return [str compare:@"true"] == NSOrderedSame;
	else
		return value;
}

+ (int)intValue:(NSString*)name missing:(int)value
{
	NSString* str = [Settings stringValue:name missing:nil];
	
	if (str)
	{
		int result = [str intValue];
		if (result != 0)
		{
			return result;
		}
		else
		{
			if ([str compare:@"0"] == NSOrderedSame)
			{
				return 0;
			}
			else
			{
				NSString* mesg = [NSString stringWithFormat:@"Setting %@'s value is '%@' which is not a valid integer.", name, str];
				[TranscriptController writeError:mesg];

				return value;
			}
		}
	}
	else
	{
		return value;
	}
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
