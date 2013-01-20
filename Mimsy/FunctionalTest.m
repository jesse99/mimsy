#import "FunctionalTest.h"

#include <lua.h>
#include <lauxlib.h>

#import "AppDelegate.h"
#import "Assert.h"
#import "Glob.h"
#import "Logger.h"
#import "TranscriptController.h"
#import "Utils.h"

static const char* _ftestPath;
static NSString* _failure;

// ---- Internal Functions -------------------------------------------------
static void addTestItems(NSMenu* testMenu)
{
	NSString* dir = [NSString stringWithUTF8String:_ftestPath];
	Glob* glob = [[Glob alloc] initWithGlob:@"*.lua"];
	
	NSError* error = nil;
	[Utils enumerateDeepDir:dir glob:glob error:&error block:
		 ^(NSString* path)
		 {
			 NSString* name = [[path lastPathComponent] stringByDeletingPathExtension];
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

static int failed(lua_State* state)
{
	const char* reason = lua_tostring(state, 1);
	_failure = [NSString stringWithUTF8String:reason];
	
	return 0;
}

static lua_State* createLua()
{
	lua_State* state = luaL_newstate();
	//luaL_openlibs(state);
	lua_register(state, "failed", failed);
	
	return state;
}

static void destroyLua(lua_State* state)
{
	lua_close(state);
}

static void runTest(NSString* path)
{
	NSError* error = nil;
	NSString* script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	if (error == nil)
	{
		lua_State* state = createLua();		// not sure how expensive this is, but it should be possible to create it once
		int err = luaL_dostring(state, script.UTF8String);
		if (err)
		{
			if (!_failure)
				_failure = [NSString stringWithUTF8String:lua_tostring(state, -1)];
			lua_pop(state, 1);
		}
		destroyLua(state);
	}
	else
	{
		NSString* reason = [error localizedFailureReason];
		_failure = [NSString stringWithFormat:@"failed to load '%@': %@", path, reason];
	}
}

// ---- Public Functions -------------------------------------------------
void initFunctionalTests(void)
{
	ASSERT(!_ftestPath);
	
	_ftestPath = getenv("MIMSY_FTEST");
	if (_ftestPath)
		createMenu();
}

void runFunctionalTests(void)
{
	NSString* dir = [NSString stringWithUTF8String:_ftestPath];
	Glob* glob = [[Glob alloc] initWithGlob:@"*.lua"];
	
	__block int numPassed = 0;
	__block int numFailed = 0;
	[TranscriptController writeCommand:@"Running functional tests:\n"];
	
	NSError* error = nil;
	[Utils enumerateDeepDir:dir glob:glob error:&error block:
	 ^(NSString* path)
	 {
		 [TranscriptController writeStdout:@"   "];
		 runFunctionalTest(path);
		 
		 if (_failure)
			 ++numFailed;
		 else
			 ++numPassed;
	 }
	 ];
	if (error)
		[TranscriptController writeError:[error localizedFailureReason]];
	
	if (numFailed == 0)
		[TranscriptController writeStdout:[NSString stringWithFormat:@"All %d tests passed.\n", numPassed]];
	else if (numPassed == 0)
		[TranscriptController writeStdout:[NSString stringWithFormat:@"All %d tests FAILED.\n", numFailed]];
	else if (numFailed == 1)
		[TranscriptController writeStdout:[NSString stringWithFormat:@"%d tests passed and 1 test FAILED.\n", numPassed]];
	else
		[TranscriptController writeStdout:[NSString stringWithFormat:@"%d tests passed and %d tests FAILED.\n", numPassed, numFailed]];
}

void runFunctionalTest(NSString* path)
{
	NSString* name = [[path lastPathComponent] stringByDeletingPathExtension];
	[TranscriptController writeStdout:name];
	[TranscriptController writeStdout:@"..."];
	
	_failure = NULL;
	runTest(path);
	
	if (_failure)
	{
		[TranscriptController writeStderr:_failure];
	}
	else
	{
		[TranscriptController writeStdout:@"ok"];
	}
	[TranscriptController writeStdout:@"\n"];
}
