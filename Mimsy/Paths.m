#import "Paths.h"

#import "Logger.h"

static NSString* _caches;
static bool _triedCaches;

@implementation Paths

+ (NSString*)caches
{
	if (!_triedCaches)
	{
		NSFileManager* fm = [NSFileManager defaultManager];
		NSArray* urls = [fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
		if (urls.count > 0)
		{
			NSURL* url = urls[0];
			_caches = [url path];
			_caches = [_caches stringByAppendingPathComponent:@"Mimsy"];
			
			if (![fm fileExistsAtPath:_caches])
			{
				NSError* error = nil;
				[fm createDirectoryAtPath:_caches withIntermediateDirectories:YES attributes:nil error:&error];
				if (error)
				{
					LOG_ERROR("Mimsy", "Couldn't create '%s': %s", STR(_caches), STR([error localizedFailureReason]));
					_caches = nil;
				}
			}
		}
		else
		{
			LOG_ERROR("Mimsy", "URLsForDirectory:NSCachesDirectory failed to find any directories");
		}
		_triedCaches = true;
	}
	
	return _caches;
}

// TODO: This is not right. We need to support installing files from the
// bundle and use the install directory instead.
+ (NSString*)installedDir:(NSString*)name
{
	NSString* resources = NSBundle.mainBundle.resourcePath;
	return [resources stringByAppendingPathComponent:name];
	
}

@end
