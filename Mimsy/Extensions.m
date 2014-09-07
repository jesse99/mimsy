#import "Extensions.h"

#import <lualib.h>
#import <lauxlib.h>

#import "Glob.h"
#import "Paths.h"
#import "ProcFileSystem.h"
#import "TranscriptController.h"
#import "Utils.h"

#ifdef __clang_analyzer__
	void luaL_error2(lua_State *L, const char *fmt, ...) __attribute__((__noreturn__));
#else
	#define luaL_error2 luaL_error
#endif

// This is intended to catch programmer errors made within lua scripts. But because
// scripts may be edited while Mimsy is running the errors act more like runtime
// errors than asserts (which in theory can be disabled in release with no harm).
// TODO: may want to rename this LUA_CHECK or something.
#define LUA_ASSERT(e, format, ...)						\
	do													\
	{													\
		if (__builtin_expect(!(e), 0))					\
		{												\
			__PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS			\
			luaL_error2(state, format, ##__VA_ARGS__);	\
			__PRAGMA_POP_NO_EXTRA_ARG_WARNINGS			\
		}												\
	} while(0)

@interface Extension : NSObject

- (id)init:(struct lua_State*)state;

@property NSString* name;
@property NSString* version;
@property NSString* url;

@property NSMutableDictionary* priorities;	// wached file path => priority
@property NSMutableDictionary* watched;		// wached file path => lua function name

@property (readonly) struct lua_State* state;

@end

@implementation Extension

- (id)init:(struct lua_State*)state
{
	self = [super init];
	if (self)
	{
		_version = @"?";
		_url = @"";
		_priorities = [NSMutableDictionary new];
		_watched = [NSMutableDictionary new];
		_state = state;
	}
    
    return self;
}

- (void)callInit
{
	lua_getglobal(self.state, "init");
	if (lua_pcall(self.state, 0, 0, 0) != 0)				// 0 args, no result
	{
		NSString* reason = [NSString stringWithUTF8String:lua_tostring(_state, -1)];
		LOG("Error", "%s init failed: %s", STR(self.name), STR(reason));
	}
}

- (bool)invoke:(NSString*)path
{
	NSString* fname = self.watched[path];
	ASSERT(fname);

	bool handled = false;
	inMainThread = true;

	lua_getglobal(self.state, fname.UTF8String);
	if (lua_pcall(self.state, 0, 1, 0) == 0)				// 0 args, bool result
	{
		handled = lua_toboolean(self.state, 1);
		lua_pop(self.state, 1);
	}
	else
	{
		NSString* reason = [NSString stringWithUTF8String:lua_tostring(_state, -1)];
		LOG("Error", "%s invoke failed: %s", STR(self.name), STR(reason));
	}
	inMainThread = false;

	return handled;
}

@end

static NSMutableDictionary* _extensions;	// script path => Extension
static NSMutableDictionary* _watching;		// path => [Extension]

// function set_extension_name(extension, name)
static int set_extension_name(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	Extension* extension = (__bridge Extension*) lua_touserdata(state, -1);
	const char* name = lua_tostring(state, 2);
	
	LUA_ASSERT(extension != NULL, "extension was NULL");
	LUA_ASSERT(name != NULL && strlen(name) > 0, "name was NULL or empty");
	
	[extension setName:[NSString stringWithUTF8String:name]];
	
	return 0;
}

// function set_extension_version(extension, version)
static int set_extension_version(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	Extension* extension = (__bridge Extension*) lua_touserdata(state, -1);
	const char* version = lua_tostring(state, 2);
	
	LUA_ASSERT(extension != NULL, "extension was NULL");
	LUA_ASSERT(version != NULL && strlen(version) > 0, "version was NULL or empty");
	
	[extension setVersion:[NSString stringWithUTF8String:version]];
	
	return 0;
}

// function set_extension_url(extension, url)
static int set_extension_url(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	Extension* extension = (__bridge Extension*) lua_touserdata(state, -1);
	const char* url = lua_tostring(state, 2);
	
	LUA_ASSERT(extension != NULL, "extension was NULL");
	LUA_ASSERT(url != NULL && strlen(url) > 0, "url was NULL or empty");
	
	[extension setUrl:[NSString stringWithUTF8String:url]];
	
	return 0;
}

// function watch_file(extension, priority, path, fname)
static int watch_file(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	Extension* extension = (__bridge Extension*) lua_touserdata(state, -1);
	double priority = lua_tonumber(state, 2);
	const char* path = lua_tostring(state, 3);
	const char* fname = lua_tostring(state, 4);
	
	LUA_ASSERT(extension != NULL, "extension was NULL");
	LUA_ASSERT(path != NULL && strlen(path) > 0, "path was NULL or empty");
	LUA_ASSERT(fname != NULL && strlen(fname) > 0, "function name was NULL or empty");
	
	NSString* key = [NSString stringWithUTF8String:path];
	[extension.priorities setObject:@(priority) forKey:key];
	[extension.watched setObject:[NSString stringWithUTF8String:fname] forKey:key];
	
	[Extensions watch:key extension:extension];
		
	return 0;
}

static void initMimsyMethods(struct lua_State* state, Extension* extension)
{
	luaL_Reg methods[] =
	{
		{"set_extension_name", set_extension_name},
		{"set_extension_version", set_extension_version},
		{"set_extension_url", set_extension_url},
		{"watch_file", watch_file},
		{NULL, NULL}
	};
	luaL_register(state, "mimsy", methods);
	
	lua_pushlightuserdata(state, (__bridge void*) extension);
	lua_setfield(state, -2, "target");
	
	lua_setglobal(state, "mimsy");
}

@implementation Extensions

+ (void)setup
{
	if (_extensions)
		[Extensions cleanup];
	_extensions = [NSMutableDictionary new];
	_watching = [NSMutableDictionary new];
	
	NSString* dir = [Paths installedDir:@"extensions"];
	Glob* glob = [[Glob alloc] initWithGlob:@"*.lua"];
	
	NSError* error = nil;
	[Utils enumerateDir:dir glob:glob error:&error block:
		 ^(NSString* path)
		 {
			 [self startScript:path];
		 }];
	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		LOG("Error", "Error processing %s: %s", STR(dir), STR(reason));
	}
}

+ (void)cleanup
{
	for (NSString* path in _extensions)
	{
		Extension* extension = _extensions[path];
		lua_close(extension.state);
	}
}

+ (void)watch:(NSString*)path extension:(Extension*)extension
{
	NSMutableArray* extensions = _watching[path];
	if (!extensions)
		extensions = [NSMutableArray new];
	
	[extensions addObject:extension];
	
	[extensions sortUsingComparator:^NSComparisonResult(Extension* lhs, Extension* rhs) {
		NSNumber* lhsN = lhs.priorities[path];
		NSNumber* rhsN = rhs.priorities[path];
		return [rhsN compare:lhsN];
	}];
	
	_watching[path] = extensions;
}

+ (bool)invoke:(NSString*)path
{
	bool handled = false;
	
	NSArray* extensions = _watching[path];
	for (Extension* extension in extensions)
	{
		handled = [extension invoke:path];
		if (handled)
			break;
	}
	
	return handled;
}

+ (void)startScript:(NSString*)path
{
	lua_State* state = luaL_newstate();
	luaL_openlibs(state);
	
	Extension* extension = [[Extension alloc] init:state];
	initMimsyMethods(state, extension);

	int err = luaL_loadfile(state, path.UTF8String);
	if (err == 0)
	{
		if (lua_pcall(state, 0, 0, 0))                  /* PRIMING RUN. FORGET THIS AND YOU'RE TOAST */
			LOG("Error", "lua_pcall() failed");          /* Error out if Lua file has an error */
		else
		{
			[extension callInit];
			[_extensions setObject:extension forKey:path];
		}
	}
	else if (err == LUA_ERRFILE)
	{
		LOG("Error", "Error loading %s: failed to open the file", STR(path));
	}
	else if (err == LUA_ERRSYNTAX)
	{
		LOG("Error", "Error loading %s: syntax error", STR(path));
	}
	else if (err == LUA_ERRMEM)
	{
		LOG("Error", "Error loading %s: out of memory", STR(path));
	}
	else
	{
		LOG("Error", "Error loading %s: unknown error", STR(path));
	}
}

#if 0
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
#endif

@end
