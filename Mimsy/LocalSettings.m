#import "LocalSettings.h"

#import "Assert.h"
#import "TranscriptController.h"

@implementation LocalSettings
{
	NSString* _fileName;
	NSMutableArray* _keys;
	NSMutableArray* _values;
	NSMutableArray* _dupes;
}

- (id)initWithFileName:(NSString*)name
{
	ASSERT(name != nil);

	_fileName = name;
	
	_keys   = [NSMutableArray new];
	_values = [NSMutableArray new];
	_dupes  = [NSMutableArray new];

	return self;
}

- (void)addKey:(NSString*)key value:(NSString*)value
{
	ASSERT(key != nil);
	ASSERT(value != nil);
	
	[_keys addObject:key];
	[_values addObject:value];
}

// It'd be nicer to use something like a multimap here but there should
// be few enough entries that a linear algorithm should be fine.
- (NSString*)findKey:(NSString*)key
{
	ASSERT(key != nil);
	NSString* result = nil;
	
	for (NSUInteger i = 0; i < _keys.count; ++i)
	{
		NSString* candidate = _keys[i];
		if ([candidate compare:key] == NSOrderedSame)
		{
			if (!result)
			{
				result = _values[i];
			}
			else if ([_dupes indexOfObject:key] == NSNotFound)
			{
				// This can get annoying so we won't warn every time.
				NSString* mesg = [NSString stringWithFormat:@"%@ has multiple %@ settings", _fileName, key];
				[TranscriptController writeError:mesg];
				[_dupes addObject:key];
			}
		}
	}
	
	return result;	
}

- (NSArray*)findAllKeys:(NSString*)key
{
	ASSERT(key != nil);
	NSMutableArray* result = [NSMutableArray new];
	
	for (NSUInteger i = 0; i < _keys.count; ++i)
	{
		NSString* candidate = _keys[i];
		if ([candidate compare:key] == NSOrderedSame)
		{
			[result addObject:_values[i]];
		}
	}
	
	return result;
}

@end
