#import "Extensions.h"

#import <lualib.h>
#import <lauxlib.h>

#import "AppSettings.h"
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

#define BLOCK_TIMEOUT 5

// We don't want to lock up the UI if an extension malfunctions but extensions also need
// to be able to safely access UI state. So we spin up a new thread for extensions but
// block the main thread until the extension either finishes or times out.
static bool block_timed_out(void (^block)())
{
	dispatch_semaphore_t sem = dispatch_semaphore_create(0);    // note that ARC releases this for us
	
	dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(concurrent,
	   ^{
		   block();
		   dispatch_semaphore_signal(sem);
	   });

	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, BLOCK_TIMEOUT*NSEC_PER_SEC);
	return dispatch_semaphore_wait(sem, timeout) != 0;
}

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

- (bool)callInit:(NSString*)path
{
	__block NSString* mesg = nil;
	
	bool timedout = block_timed_out(^{
		lua_getglobal(self.state, "init");
        lua_pushstring(self.state, path.stringByDeletingLastPathComponent.UTF8String);
		if (lua_pcall(self.state, 1, 0, 0) == 0)				// 1 arg, no result
		{
			LOG("Extensions", "loaded %s %s", STR(self.name), STR(self.version));
		}
		else
		{
			NSString* reason = [NSString stringWithUTF8String:lua_tostring(_state, -1)];
			mesg = [NSString stringWithFormat:@"%@ extension's init failed: %@", self.name, reason];
		}
	});
	
	if (timedout)
		mesg = [NSString stringWithFormat:@"%@ extension's init took longer than %ds to run", self.name, BLOCK_TIMEOUT];
	
	if (mesg)
	{
		LOG("Error", "%s", STR(mesg));
		[TranscriptController writeError:mesg];
	}
		
	return mesg == nil;
}

- (void)teardown
{
	lua_close(_state);
}

- (bool)invoke:(NSString*)path
{
	NSString* fname = self.watched[path];
	ASSERT(fname);
	
	__block bool handled = false;
	__block NSString* mesg = nil;
    __block bool timedout = false;
	
    // invoke should always be called on the main thread but even then we seem to get deadlocks
    // on occasion. But using dispatch_after ensures that we always call into extensions at a
    // known good point.
	dispatch_queue_t main = dispatch_get_main_queue();
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 0*NSEC_PER_MSEC);
    dispatch_after(delay, main, ^{
        timedout = block_timed_out(^{
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
                mesg = [NSString stringWithFormat:@"%@ invoke failed: %@", self.name, reason];
            }
        });
    });

	if (timedout)
		mesg = [NSString stringWithFormat:@"%@ extension's invoke for '%@' took longer than %ds to run", self.name, path, BLOCK_TIMEOUT];
	
	if (mesg)
	{
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
		[_task setEnvironment:[self _environment]];
		[_task setStandardError:[NSPipe pipe]];
		[_task setStandardInput:[NSPipe pipe]];
		[_task setStandardOutput:[NSPipe pipe]];
		[_task launch];
		
		// launch can throw so we'll go ahead and throw too.
		if (block_timed_out(^{[self _initialize];}))
			[NSException raise:@"ExeExtension failed" format:@"took more than %ds to load", BLOCK_TIMEOUT];

		LOG("Extensions", "loaded %s %s", STR(self.name), STR(self.version));
	}
	@catch (NSException *exception)
	{
		NSString* mesg = [NSString stringWithFormat:@"Starting '%@' failed: %@", path, exception.reason];
		LOG("Error", "%s", STR(mesg));
		[TranscriptController writeError:mesg];
		
		self = nil;
	}
    
    return self;
}

- (NSDictionary*)_environment
{
	NSMutableDictionary* env = [NSMutableDictionary new];
	[env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
	
	NSArray* newPaths = [AppSettings stringValues:@"AppendPath"];
	if (newPaths && newPaths.count > 0)
	{
		NSString* suffix = [newPaths componentsJoinedByString:@":"];
		
		NSString* paths = env[@"PATH"];
		if (paths && paths.length > 0)
			paths = [NSString stringWithFormat:@"%@:%@", paths, suffix];
		else
			paths = suffix;
		
		env[@"PATH"] = paths;
	}
	
	return env;
}

- (void)teardown
{
	[_task terminate];
	_task = nil;
}

- (bool)invoke:(NSString*)path
{
	__block NSString* line = @"false";
	
	bool timed_out = block_timed_out(^{
		NSPipe* pipe = [_task standardInput];
		NSFileHandle* stdin = [pipe fileHandleForWriting];
		
		NSString* path2 = [path stringByAppendingString:@"\n"];
		NSData* data = [path2 dataUsingEncoding:NSUTF8StringEncoding];
		[stdin writeData:data];
		
		line = [self _readLine];
	});
	
	if (timed_out)
	{
		NSString* mesg = [NSString stringWithFormat:@"%@ extension took longer than %ds to handle write to %@", self.name, BLOCK_TIMEOUT, path];
		LOG("Error", "%s", STR(mesg));
		[TranscriptController writeError:mesg];
	}
	
	NSPipe* pipe = [_task standardError];
	NSFileHandle* stderr = [pipe fileHandleForReading];
	NSData* data = [stderr availableDataNonBlocking];
	if (data && data.length > 0)
	{
		NSString* text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		[TranscriptController writeStderr:text];
	}
	
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
		
		if ([line startsWith:@"name\f"])
			self.name = [line substringFromIndex:@"name\f".length];
		
		else if ([line startsWith:@"version\f"])
			self.version = [line substringFromIndex:@"version\f".length];
		
		else if ([line startsWith:@"url\f"])
			self.url = [line substringFromIndex:@"url\f".length];
		
		else if ([line startsWith:@"watch\f"])
		{
			line = [line substringFromIndex:@"watch\f".length];

			NSRange range = [line rangeOfString:@"\f"];
			if (range.location == NSNotFound)
			{
				error = @"Missing form feed";
				break;
			}
			
			NSString* key = [line substringToIndex:range.location];
			NSString* path = [line substringFromIndex:range.location+1];
			
			double priority = [key doubleValue];
			if (priority == 0.0)
			{
				error = @"Unexpected watch line";
			}
			else if (![path startsWith:@"/Volumes/Mimsy/"])
			{
				error = [NSString stringWithFormat:@"'%@' doesn't start with /Volumes/Mimsy/", path];
			}
			else
			{
				path = [path substringFromIndex:[@"/Volumes/Mimsy" length]];

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
	
	// The file system strips off the "/Volumes/Mimsy from paths so to keep things
	// consistent internally we always do the same.
	NSString* key = [NSString stringWithUTF8String:path];
	LUA_ASSERT([key startsWith:@"/Volumes/Mimsy/"], "path doesn't start with '/Volumes/Mimsy/'");
	key = [key substringFromIndex:[@"/Volumes/Mimsy" length]];
	
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
             {
                 if (![path endsWith:@".inc.lua"])
                     [self _startScript:path];
             }
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
            if ([extension callInit:path])
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
	if (extension)
		[_extensions setObject:extension forKey:path];
}

@end
