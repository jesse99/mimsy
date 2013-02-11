#import "WindowsDatabase.h"

#import "Assert.h"
#import "Metadata.h"
//#import "Paths.h"

@interface WindowState : NSObject <NSCoding>
@property struct WindowInfo info;
@end

@implementation WindowState
{
	struct WindowInfo _info;
}

- (id)initWithInfo:(const struct WindowInfo*)info
{
	self = [super init];
	if (self)
	{
		_info = *info;
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self = [super init];
    if (self)
	{
		_info.frame = [decoder decodeRect];
		_info.length = [decoder decodeInt64ForKey:@"length"];
		_info.origin = [decoder decodePoint];
		_info.selection.length = (NSUInteger)[decoder decodeInt64ForKey:@"sel_len"];
		_info.selection.location = (NSUInteger)[decoder decodeInt64ForKey:@"sel_loc"];
		_info.wordWrap = [decoder decodeBoolForKey:@"wrap"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
	[encoder encodeRect:_info.frame];
	[encoder encodeInt64:_info.length forKey:@"length"];
	[encoder encodePoint:_info.origin];
	[encoder encodeInt64:(int64_t)_info.selection.length forKey:@"sel_len"];
	[encoder encodeInt64:(int64_t)_info.selection.location forKey:@"sel_loc"];
	[encoder encodeBool:_info.wordWrap forKey:@"wrap"];
}
@end

@implementation WindowsDatabase

+ (bool) getInfo:(struct WindowInfo*)info forPath:(NSString*)path
{
	NSError* error = nil;
	WindowState* state = [Metadata readCriticalDataFrom:path named:@"window_state" outError:&error];
	if (state)
		*info = state.info;
	return state;
}

+ (void) saveInfo:(const struct WindowInfo*)info forPath:(NSString*)path
{
	WindowState* state = [[WindowState alloc] initWithInfo:info];
	[Metadata writeCriticalDataTo:path named:@"window_state" with:state];
}

@end
