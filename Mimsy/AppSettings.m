#import "AppSettings.h"

#import "AppDelegate.h"
#import "DirectoryController.h"
#import "Language.h"
#import "LocalSettings.h"
#import "Logger.h"
#import "TextController.h"
#import "TranscriptController.h"

static NSMutableArray* _settingNames;
static LocalSettings* _cachedAppSettings;
static LocalSettings* _cachedDirSettings;
static LocalSettings* _cachedLangSettings;

@implementation AppSettings

+ (void)registerSetting:(NSString*)name
{
	if (!_settingNames)
	{
		// These are initialized in main.m
		_settingNames = [NSMutableArray new];

		_cachedAppSettings  = nil;
		_cachedDirSettings = nil;
		_cachedLangSettings = nil;

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowOrderChanged:) name:@"SettingsChanged" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowOrderChanged:) name:@"DirectoryChanged" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowOrderChanged:) name:@"LanguagesChanged" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowOrderChanged:) name:NSWindowDidResignMainNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowOrderChanged:) name:NSWindowDidBecomeMainNotification object:nil];
	}
	
	ASSERT(name);
	[_settingNames addObject:name];
}

+ (id)updateAppSettings
{
	AppDelegate* delegate = (AppDelegate*) [NSApp delegate];
	LocalSettings* appSettings = delegate.settings;
	
	DirectoryController* controller = [DirectoryController getCurrentController];
	LocalSettings* dirSettings = controller ? controller.settings : nil;
	
	TextController* tc = [TextController frontmost];
	LocalSettings* langSettings = tc && tc.language ? tc.language.settings : nil;

	if (![LocalSettings is:appSettings equalTo:_cachedAppSettings] ||
		![LocalSettings is:dirSettings equalTo:_cachedDirSettings] ||
		![LocalSettings is:langSettings equalTo:_cachedLangSettings])
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AppSettingsChanged" object:self];
	
	_cachedAppSettings = [appSettings copy];
	_cachedDirSettings = [dirSettings copy];
	_cachedLangSettings = [langSettings copy];
	
	return nil;		// we need to return nil to keep ARC (and our asserts) happy
}

+ (void)windowOrderChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
	// This is called when we get a new main window or resign the current one.
	// Because these events are often paired we'll defer doing the work for a
	// tenth of a second.
	[AppDelegate execute:@"update app settings" withSelector:@selector(updateAppSettings) withObject:self afterDelay:0.1];
}

+ (bool)isSetting:(NSString*)name
{
	ASSERT(name);
	return [_settingNames containsObject:name];
}

+ (NSString*)stringValue:(NSString*)name missing:(NSString*)value
{
	ASSERT([AppSettings isSetting:name]);
	NSString* result = nil;
	
	if (!result)
	{
		TextController* controller = [TextController frontmost];
		result = controller && controller.language ? [controller.language.settings findValueForKey:name] : nil;
	}
	
	if (!result)
	{
		DirectoryController* controller = [DirectoryController getCurrentController];
		result = controller ? [controller.settings findValueForKey:name] : nil;
	}
	
	if (!result)
	{
		AppDelegate* delegate = (AppDelegate*) [NSApp delegate];
		result = [delegate.settings findValueForKey:name];
	}
	
	if (!result)
	{
		result = value;
	}
	
	return result;
}

+ (NSArray*)stringValues:(NSString*)name
{
	ASSERT([AppSettings isSetting:name]);
	NSMutableArray* result = [NSMutableArray new];
	
	AppDelegate* delegate = (AppDelegate*) [NSApp delegate];
	[result addObjectsFromArray:[delegate.settings findValuesForKey:name]];
	
	DirectoryController* controller = [DirectoryController getCurrentController];
	if (controller)
		[result addObjectsFromArray:[controller.settings findValuesForKey:name]];
	
	TextController* tc = [TextController frontmost];
	if (tc && tc.language)
		[result addObjectsFromArray:[tc.language.settings findValuesForKey:name]];
	
	return result;
}

+ (void)enumerate:(NSString*) key with:(void (^)(NSString* fileName, NSString* value))block
{
	AppDelegate* delegate = (AppDelegate*) [NSApp delegate];
	[delegate.settings enumerate:key with:block];
	
	DirectoryController* controller = [DirectoryController getCurrentController];
	if (controller)
		[controller.settings enumerate:key with:block];
	
	TextController* tc = [TextController frontmost];
	if (tc && tc.language)
		[tc.language.settings enumerate:key with:block];
}

// ---- convenience methods ----------------------------------
+ (bool)boolValue:(NSString*)name missing:(bool)value
{
	NSString* str = [AppSettings stringValue:name missing:nil];
	
	if (str)
		return [str compare:@"true"] == NSOrderedSame;
	else
		return value;
}

+ (int)intValue:(NSString*)name missing:(int)value
{
	NSString* str = [AppSettings stringValue:name missing:nil];
	
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

+ (unsigned int)uintValue:(NSString*)name missing:(unsigned int)value
{
	NSString* str = [AppSettings stringValue:name missing:nil];
	
	if (str)
	{
		int result = [str intValue];
		if (result > 0)
		{
			return (unsigned int) result;
		}
		else
		{
			if ([str compare:@"0"] == NSOrderedSame)
			{
				return 0;
			}
			else
			{
				NSString* mesg = [NSString stringWithFormat:@"Setting %@'s value is '%@' which is not a valid unsigned integer.", name, str];
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

@end
