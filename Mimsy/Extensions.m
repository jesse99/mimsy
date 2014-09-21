#import "Extensions.h"

#import <lualib.h>
#import <lauxlib.h>

#import "FileHandleCategory.h"
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

static NSMutableDictionary* _extensions;	// script path => BaseExtension
static NSMutableDictionary* _watching;		// path => [BaseExtension]

static BaseExtension* _executing;			// the extension currently being executed (or nil)

// ---- class BaseExtension --------------------------------------------------------------
@interface BaseExtension : NSObject

@property NSString* name;
@property NSString* version;
@property NSString* url;

@property NSMutableDictionary* priorities;	// wached file path => priority

@end

@implementation BaseExtension

- (id)init
{
	self = [super init];
	if (self)
	{
		_version = @"?";
		_url = @"";
		_priorities = [NSMutableDictionary new];
	}
    
    return self;
}

- (void)teardown
{
	ASSERT(false);	// derived classes need to override this
}

- (bool)invoke:(NSString*)path
{
	UNUSED(path);
	ASSERT(false);	// derived classes need to override this
}

@end

// ---- class LuaExtension --------------------------------------------------------------
@interface LuaExtension : BaseExtension

- (id)init:(struct lua_State*)state;

@property NSMutableDictionary* watched;		// wached file path => lua function name
@property (readonly) struct lua_State* state;

@end

@implementation LuaExtension

- (id)init:(struct lua_State*)state
{
	self = [super init];
	if (self)
	{
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
		NSString* mesg = [NSString stringWithFormat:@"%@ init failed: %@", self.name, reason];
		LOG("Error", "%s", STR(mesg));
		[TranscriptController writeError:mesg];
	}
}

- (void)teardown
{
	lua_close(_state);
}

- (bool)invoke:(NSString*)path
{
	NSString* fname = self.watched[path];
	ASSERT(fname);
	
	bool handled = false;
	
	LOG("Extensions:Verbose", "invoking %s for %s", STR(fname), STR(self.name));
	lua_getglobal(self.state, fname.UTF8String);
	if (lua_pcall(self.state, 0, 1, 0) == 0)				// 0 args, bool result
	{
		handled = lua_toboolean(self.state, 1);
		lua_pop(self.state, 1);
		LOG("Extensions:Verbose", "   done invoking %s", STR(self.name));
	}
	else
	{
		NSString* reason = [NSString stringWithUTF8String:lua_tostring(_state, -1)];
		NSString* mesg = [NSString stringWithFormat:@"%@ invoke failed: %@", self.name, reason];
		LOG("Error", "%s", STR(mesg));
		[TranscriptController writeError:mesg];
	}
	
	return handled;
}

@end

// ---- class ExeExtension --------------------------------------------------------------
@interface ExeExtension : BaseExtension

- (id)init:(NSString*)path;

@end

@implementation ExeExtension
{
	NSString* _path;
	NSTask* _task;
}

- (id)init:(NSString*)path
{
	self = [super init];
	
	@try
	{
		_path = path;
		
		_task = [NSTask new];
		[_task setLaunchPath:path];
		[_task setArguments:@[]];
		[_task setStandardError:[NSPipe pipe]];
		[_task setStandardInput:[NSPipe pipe]];
		[_task setStandardOutput:[NSPipe pipe]];
		[_task launch];
		
		[self _initialize];
	}
	@catch (NSException *exception)
	{
		NSString* mesg = [NSString stringWithFormat:@"Starting '%@' failed: %@", path, exception.reason];
		LOG("Error", "%s", STR(mesg));
		[TranscriptController writeError:mesg];
	}
    
    return self;
}

- (void)teardown
{
	[_task terminate];
	_task = nil;
}

- (bool)invoke:(NSString*)path
{
	NSPipe* pipe = [_task standardInput];
	NSFileHandle* stdin = [pipe fileHandleForWriting];
	
	path = [path stringByAppendingString:@"\n"];
	NSData* data = [path dataUsingEncoding:NSUTF8StringEncoding];
	[stdin writeData:data];

	NSString* line = [self _readLine];
	return [line compare:@"true"] == NSOrderedSame;
}

- (void)_initialize
{
	NSString* error = nil;
	NSString* line = nil;
	
	while (!error)
	{
		line = [self _readLine];
		if (line.length == 0)
			break;
		
		if ([line startsWith:@"name:"])
			self.name = [line substringFromIndex:@"name:".length];
		
		else if ([line startsWith:@"version:"])
			self.version = [line substringFromIndex:@"version:".length];
		
		else if ([line startsWith:@"url:"])
			self.url = [line substringFromIndex:@"url:".length];
		
		else if ([line startsWith:@"watch:"])
		{
			line = [line substringFromIndex:@"watch:".length];

			NSRange range = [line rangeOfString:@":"];
			if (range.location == NSNotFound)
			{
				error = @"Missing colon";
				break;
			}
			
			NSString* key = [line substringToIndex:range.location];
			NSString* path = [line substringFromIndex:range.location+1];
			
			double priority = [key doubleValue];
			if (priority == 0.0)
			{
				error = @"Unexpected watch line";
			}
			else
			{
				[self.priorities setObject:@(priority) forKey:path];
				[Extensions watch:path extension:self];
			}
		}
		
		else
		{
			error = @"Unknown key";
		}
	}
	
	if (error)
	{
		NSString* mesg = [NSString stringWithFormat:@"%@ '%@': %@", error, _path, line];
		LOG("Error", "%s", STR(mesg));
		[TranscriptController writeError:mesg];
	}
}

- (NSString*)_readLine
{
	NSPipe* pipe = [_task standardOutput];
	NSFileHandle* stdout = [pipe fileHandleForReading];
	return [stdout readLine];
}

@end

// ---- Helpers --------------------------------------------------------------

// function set_extension_name(extension, name)
static int set_extension_name(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	LuaExtension* extension = (__bridge LuaExtension*) lua_touserdata(state, -1);
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
	LuaExtension* extension = (__bridge LuaExtension*) lua_touserdata(state, -1);
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
	LuaExtension* extension = (__bridge LuaExtension*) lua_touserdata(state, -1);
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
	LuaExtension* extension = (__bridge LuaExtension*) lua_touserdata(state, -1);
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

static void initMimsyMethods(struct lua_State* state, LuaExtension* extension)
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

// ---- class Extensions --------------------------------------------------------------
@implementation Extensions

+ (void)setup
{
	if (_extensions)
		[Extensions cleanup];
	_extensions = [NSMutableDictionary new];
	_watching = [NSMutableDictionary new];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"LoadingExtensions" object:self];
	
	NSError* error = nil;
	NSString* dir = [Paths installedDir:@"extensions"];
	[Utils enumerateDir:dir glob:nil error:&error block:
		 ^(NSString* path)
		 {
			 if ([path endsWith:@".lua"])
				 [self _startScript:path];

			 else if ([[NSFileManager defaultManager] isExecutableFileAtPath:path])
				 [self _startExe:path];
		 }];
	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Error processing %@: %@", dir, reason];
		LOG("Error", "%s", STR(mesg));
		[TranscriptController writeError:mesg];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"LoadedExtensions" object:self];
}

+ (void)cleanup
{
	for (NSString* path in _extensions)
	{
		BaseExtension* extension = _extensions[path];
		[extension teardown];
	}
}

+ (void)watch:(NSString*)path extension:(BaseExtension*)extension
{
	NSMutableArray* extensions = _watching[path];
	if (!extensions)
		extensions = [NSMutableArray new];
	
	[extensions addObject:extension];
	
	[extensions sortUsingComparator:^NSComparisonResult(BaseExtension* lhs, BaseExtension* rhs) {
		NSNumber* lhsN = lhs.priorities[path];
		NSNumber* rhsN = rhs.priorities[path];
		return [rhsN compare:lhsN];
	}];
	
	_watching[path] = extensions;
}

+ (bool)watching:(NSString*)path
{
	// Note that we don't notify extensions about changes they have made.
	NSArray* extensions = _watching[path];
	return extensions && (extensions.count > 1 || (extensions.count == 1 && extensions[0] != _executing));
}

+ (bool)invoke:(NSString*)path
{
	bool handled = false;
	
	path = [@"/Volumes/Mimsy" stringByAppendingPathComponent:path];
	
	NSArray* extensions = _watching[path];
	for (BaseExtension* extension in extensions)
	{
		// To keep things sane we also don't support re-entrant notifications.
		if (extension != _executing)
		{
			_executing = extension;
			handled = [extension invoke:path];
			_executing = nil;
			
			if (handled)
				break;
		}
	}
	
	return handled;
}

+ (void)_startScript:(NSString*)path
{
	lua_State* state = luaL_newstate();
	luaL_openlibs(state);
	
	LuaExtension* extension = [[LuaExtension alloc] init:state];
	initMimsyMethods(state, extension);
	
	NSString* mesg = nil;
	int err = luaL_loadfile(state, path.UTF8String);
	if (err == 0)
	{
		if (lua_pcall(state, 0, 0, 0) == 0)
		{
			[extension callInit];
			[_extensions setObject:extension forKey:path];
		}
		else
		{
			mesg = @"lua extension priming failed";
		}
	}
	else if (err == LUA_ERRFILE)
	{
		mesg = [NSString stringWithFormat:@"Error loading %@: failed to open the file", path];
	}
	else if (err == LUA_ERRSYNTAX)
	{
		mesg = [NSString stringWithUTF8String:lua_tostring(state, -1)];
	}
	else if (err == LUA_ERRMEM)
	{
		mesg = [NSString stringWithFormat:@"Error loading %@: out of memory", path];
	}
	else
	{
		mesg = [NSString stringWithFormat:@"Error loading %@: unknown error", path];
	}
	
	if (mesg)
	{
		LOG("Error", "%s", STR(mesg));
		[TranscriptController writeError:mesg];
	}
}

+ (void)_startExe:(NSString*)path
{
	UNUSED(path);
	
	ExeExtension* extension = [[ExeExtension alloc] init:path];
	[_extensions setObject:extension forKey:path];
}

@end
