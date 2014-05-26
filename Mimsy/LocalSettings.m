#import "LocalSettings.h"

#import "Assert.h"
#import "AppSettings.h"
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

- (id)copy
{
	LocalSettings* result = [[LocalSettings alloc] initWithFileName:_fileName];
	
	result->_keys  = [self->_keys copy];
	result->_values = [self->_values copy];
	result->_dupes  = [self->_dupes copy];
	
	return result;
}

+ (bool)is:(LocalSettings*)lhs equalTo:(LocalSettings*)rhs
{
	bool equal = false;
	
	if (lhs == nil && rhs == nil)
	{
		equal = true;
	}
	else if (lhs != nil && rhs != nil && [lhs->_fileName compare:rhs->_fileName] == NSOrderedSame)
	{
		equal = lhs->_keys.count == rhs->_keys.count;
		
		for (NSUInteger i = 0; i < lhs->_keys.count && equal; ++i)
		{
			equal = [lhs->_keys isEqualToArray:rhs->_keys] && [lhs->_values isEqualToArray:rhs->_values];
		}
	}
	
	return equal;
}

- (void)addKey:(NSString*)key value:(NSString*)value
{
	ASSERT(key != nil);
	ASSERT(value != nil);
	
	if ([AppSettings isSetting:key])
	{
		[_keys addObject:key];
		[_values addObject:value];
	}
	else if ([_fileName caseInsensitiveCompare:@"app.mimsy"] == NSOrderedSame)
	{
		// It's normal for language and directory files to have settings which
		// are not app settings. But everything in app.mimsy should be an app
		// setting.
		NSString* mesg = [NSString stringWithFormat:@"Ignoring unknown app.mimsy setting '%@'.", key];
		[TranscriptController writeError:mesg];
	}
}

// It'd be nicer to use something like a multimap here but there should
// be few enough entries that a linear algorithm should be fine.
- (NSString*)findValueForKey:(NSString*)key
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

- (NSArray*)findValuesForKey:(NSString*)key
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

- (void)enumerate:(NSString*) key with:(void (^)(NSString* fileName, NSString* value))block
{
	for (NSUInteger i = 0; i < _keys.count; ++i)
	{
		NSString* candidate = _keys[i];
		if ([candidate compare:key] == NSOrderedSame)
		{
			block(_fileName, _values[i]);
		}
	}
}

- (void)enumerateAll:(void (^)(NSString* key, NSString* value))block
{
	for (NSUInteger i = 0; i < _keys.count; ++i)
	{
		block(_keys[i], _values[i]);
	}
}

- (NSArray*)getKeys
{
	return _keys;
}

@end
