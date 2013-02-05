#import "StartupScripts.h"

#import <lualib.h>
#import <lauxlib.h>

#import "Glob.h"
#import "Logger.h"
#import "LuaSupport.h"
#import "Paths.h"
#import "TranscriptController.h"
#import "Utils.h"

static lua_State* _state;
static NSMutableDictionary* _hooks;		// hook name => [lua function names]

@implementation StartupScripts

+ (void)setup
{
	if (_state)
		lua_close(_state);
	
	if (!_hooks)
		_hooks = [NSMutableDictionary new];

	_state = luaL_newstate();
	luaL_openlibs(_state);
	initMethods(_state);
	
	NSString* dir = [Paths installedDir:@"scripts/startup"];
	Glob* glob = [[Glob alloc] initWithGlob:@"*.lua"];

	NSError* error = nil;
	[Utils enumerateDir:dir glob:glob error:&error block:
		^(NSString* path)
		{
			[self _loadScript:path];
		}
	];
	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		LOG_ERROR("Mimsy", "Error processing %s: %s", STR(dir), STR(reason));
	}
}

+ (void)addHook:(NSString*)hname function:(NSString*)fname
{
	NSMutableArray* names = _hooks[hname];
	if (!names)
	{
		names = [NSMutableArray new];
		_hooks[hname] = names;
	}
	
	[names addObject:fname];
}

+ (void)invokeApplyStyles:(NSDocument*)doc location:(NSUInteger)loc length:(NSUInteger)len
{
	NSMutableArray* names = _hooks[@"apply styles"];
	if (names)
	{
		for (NSString* fname in names)
		{
			lua_getglobal(_state, fname.UTF8String);
			pushTextDoc(_state, doc);
			lua_pushinteger(_state, (lua_Integer) (loc+1));
			lua_pushinteger(_state, (lua_Integer) len);
			int err = lua_pcall(_state, 3, 0, 0);		// 3 args, no result
			if (err)
			{
				[TranscriptController writeStderr:[NSString stringWithUTF8String:lua_tostring(_state, -1)]];
			}
		}
	}
}

+ (void)_loadScript:(NSString*)path
{
	if (luaL_dofile(_state, path.UTF8String))
	{
		NSString* error = [NSString stringWithUTF8String:lua_tostring(_state, -1)];
		LOG_ERROR("Mimsy", "Error loading %s: %s", STR(path), STR(error));
	}
}

@end
