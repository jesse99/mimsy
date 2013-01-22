#import "FunctionalTest.h"

#include <lualib.h>
#include <lauxlib.h>

#import "AppDelegate.h"
#import "Assert.h"
#import "Glob.h"
#import "Logger.h"
#import "LuaSupport.h"
#import "TranscriptController.h"
#import "Utils.h"

static NSString* _ftestPath;

static lua_State* _state;
static NSArray* _tests;
static NSUInteger _nextTest;
static int _numPassed;
static int _numFailed;

// ---- Internal Functions -------------------------------------------------
static void addTestItems(NSMenu* testMenu)
{
	Glob* glob = [[Glob alloc] initWithGlob:@"*.lua"];
	
	NSError* error = nil;
	[Utils enumerateDeepDir:_ftestPath glob:glob error:&error block:
		 ^(NSString* path)
		 {
			 NSString* name = [[path substringFromIndex:_ftestPath.length] stringByDeletingPathExtension];
			 NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:name action:@selector(runFTest:) keyEquivalent:@""];
			 [item setRepresentedObject:path];
			 [testMenu addItem:item];
		 }
	 ];
	if (error)
		[TranscriptController writeError:[error localizedFailureReason]];
}

static void createMenu()
{
	// Create a Test menu
	NSMenu* testMenu = [[NSMenu alloc] initWithTitle:@"Test"];
	
	NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"Run Tests" action:@selector(runFTests:) keyEquivalent:@""];
	[testMenu addItem:item];
	
	[testMenu addItem:[NSMenuItem separatorItem]];
	
	addTestItems(testMenu);
	
	// Use some clumsy code to stick it into the menubar before the Help menu.
	NSMenuItem* subitem = [[NSMenuItem alloc] initWithTitle:@"Test" action:NULL keyEquivalent:@""];
	[subitem setSubmenu:testMenu];
	
	NSMenu* menu = [NSApp mainMenu];
	[menu insertItem:subitem atIndex:[menu numberOfItems]-1];
}

static void startNextTest()
{
	if (_nextTest < _tests.count)
	{
		NSString* path = _tests[_nextTest++];
		
		NSError* error = nil;
		NSString* script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
		if (error == nil)
		{
			NSString* name = [[path substringFromIndex:_ftestPath.length] stringByDeletingPathExtension];
			if (_tests.count > 1)
				[TranscriptController writeStdout:@"   "];
			[TranscriptController writeStdout:name];
			[TranscriptController writeStdout:@"..."];
			
			int err = luaL_dostring(_state, script.UTF8String);
			if (err)
			{
				[TranscriptController writeStderr:[NSString stringWithUTF8String:lua_tostring(_state, -1)]];
				lua_pop(_state, 1);
			}
		}
		else
		{
			NSString* reason = [error localizedFailureReason];
			[TranscriptController writeStderr:[NSString stringWithFormat:@"failed to load '%@': %@", path, reason]];
		}
	}
	else
	{
		if (_tests.count > 1)
		{
			if (_numFailed == 0)
				[TranscriptController writeStdout:[NSString stringWithFormat:@"All %d tests passed.\n\n", _numPassed]];
			else if (_numPassed == 0)
				[TranscriptController writeStdout:[NSString stringWithFormat:@"All %d tests FAILED.\n\n", _numFailed]];
			else if (_numFailed == 1)
				[TranscriptController writeStdout:[NSString stringWithFormat:@"%d tests passed and 1 test FAILED.\n\n", _numPassed]];
			else
				[TranscriptController writeStdout:[NSString stringWithFormat:@"%d tests passed and %d tests FAILED.\n\n", _numPassed, _numFailed]];
		}
		_tests = nil;
	}
}

// passed(ftest)
static int ftest_passed()
{
	_numPassed++;
	[TranscriptController writeStdout:@"ok\n"];
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 0);
	dispatch_after(delay, main, ^{startNextTest();});	// defer the next test so that lua has a chance to pop the stack for the old test

	return 0;
}

// failed(ftest, reason)
static int ftest_failed()
{
	_numFailed++;
	
	const char* failure = lua_tostring(_state, 2);
	[TranscriptController writeStderr:[NSString stringWithUTF8String:failure]];
	[TranscriptController writeStdout:@"\n"];
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 0);
	dispatch_after(delay, main, ^{startNextTest();});	// defer the next test so that lua has a chance to pop the stack for the old test
	
	return 0;
}

static void initFTestMethods(lua_State* state)
{
	luaL_Reg methods[] =
	{
		{"passed", ftest_passed},
		{"failed", ftest_failed},
		{NULL, NULL}
	};
	luaL_register(state, "ftest", methods);
		
	lua_setglobal(state, "ftest");
}

static lua_State* createLua()
{
	lua_State* state = luaL_newstate();
	initFTestMethods(state);
	initMethods(state);
	
	lua_pushcfunction(state, luaopen_string);
	lua_pushliteral(state, LUA_STRLIBNAME);
	lua_call(state, 1, 0);						// 1 arg, no result
	
	lua_pushcfunction(state, luaopen_io);
	lua_pushliteral(state, LUA_IOLIBNAME);
	lua_call(state, 1, 0);						// 1 arg, no result

	return state;
}

// ---- Public Functions -------------------------------------------------
void initFunctionalTests(void)
{
	ASSERT(!_ftestPath);
	
	const char* path = getenv("MIMSY_FTEST");
	if (path)
	{
		_ftestPath = [NSString stringWithUTF8String:path];
		if (![_ftestPath hasSuffix:@"/"])
			_ftestPath = [_ftestPath stringByAppendingString:@"/"];
		
		createMenu();
		_state = createLua();
	}
}

// Unfortunately a lot of the functional tests want to do stuff like open windows
// which require event loop processing. So we need to kick off each test, return
// to the event loop, and wait until the test tells us it is finished.
void runFunctionalTests(void)
{
	if (!_tests)
	{
		__block NSMutableArray* tests = [NSMutableArray new];
		Glob* glob = [[Glob alloc] initWithGlob:@"*.lua"];
				
		NSError* error = nil;
		[Utils enumerateDeepDir:_ftestPath glob:glob error:&error block:
			 ^(NSString* path)
			 {
				 [tests addObject:path];
			 }
		 ];
		if (!error)
		{
			_tests = tests;
			_nextTest = 0;
			_numPassed = 0;
			_numFailed = 0;
			
			[TranscriptController writeCommand:@"Running functional tests:\n"];			
			startNextTest();
		}
		else
		{
			[TranscriptController writeError:[error localizedFailureReason]];
		}
	}
	else
	{
		[TranscriptController writeError:@"A functional test is already running."];
	}
}

void runFunctionalTest(NSString* path)
{
	if (!_tests)
	{
		_tests = @[path];
		_nextTest = 0;
		_numPassed = 0;
		_numFailed = 0;
		
		startNextTest();
	}
	else
	{
		[TranscriptController writeError:@"A functional test is already running."];
	}
}
