#import "Paths.h"

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
					NSLog(@"Error creating '%@: %@", _caches, [error localizedFailureReason]);
					_caches = nil;
				}
			}
		}
		else
		{
			NSLog(@"URLsForDirectory:NSCachesDirectory failed to find any directories");
		}
		_triedCaches = true;
	}
	
	return _caches;
}

@end
