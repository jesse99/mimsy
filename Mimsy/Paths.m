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
				BOOL created = [fm createDirectoryAtPath:_caches withIntermediateDirectories:YES attributes:nil error:&error];
				if (!created)
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

+ (NSString*)installedDir:(NSString*)name
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSArray* urls = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
	
	NSString* path = [urls[0] path];
	path = [path stringByAppendingPathComponent:@"Mimsy"];

	if (name)
		return [path stringByAppendingPathComponent:name];
	else
		return path;
}

@end
