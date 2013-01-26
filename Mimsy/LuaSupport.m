#import "LuaSupport.h"

#include <lauxlib.h>

#import "Assert.h"
#import "FunctionalTest.h"
#import "TextController.h"
#import "TextDocument.h"
#import "TranscriptController.h"

static void pushTextDoc(struct lua_State* state, NSDocument* doc)
{
	luaL_Reg methods[] =
	{
		{"close", doc_close},
		{"data", textdoc_data},
		{"saveas", doc_saveas},
		{NULL, NULL}
	};
	luaL_register(state, "doc", methods);
	
	lua_pushlightuserdata(state, (__bridge void*) doc);
	lua_setfield(state, -2, "target");
}

void initMethods(struct lua_State* state)
{
	luaL_Reg methods[] =
	{
		{"log", app_log},
		{"newdoc", app_newdoc},
		{"openfile", app_openfile},
		{"schedule", app_schedule},
		{NULL, NULL}
	};
	luaL_register(state, "app", methods);
	
	lua_pushlightuserdata(state, (__bridge void*) NSApp);
	lua_setfield(state, -2, "target");
	
	lua_setglobal(state, "app");
}

// openfile(app, path, success = nil, failure = nil)
int app_openfile(struct lua_State* state)
{
	const char* path = lua_tostring(state, 2);
	const char* success = luaL_optstring(state, 3, NULL);
	const char* failure = luaL_optstring(state, 4, NULL);
	
	NSURL* url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
	
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES completionHandler:
	 ^(NSDocument* document, BOOL documentWasAlreadyOpen, NSError* error)
	 {
		 (void) documentWasAlreadyOpen;
		 if (error && failure)
		 {
			 NSString* reason = [error localizedFailureReason];
			 
			 lua_getglobal(state, failure);
			 lua_pushstring(state, reason.UTF8String);
			 lua_call(state, 1, 0);						// 1 arg, no result
		 }
		 else if (!error && success)
		 {
			 if ([document isKindOfClass:[TextDocument class]])
			 {
				 lua_getglobal(state, success);
				 pushTextDoc(state, document);
				 lua_call(state, 1, 0);					// 1 arg, no result
			 }
			 else
			 {
				 lua_getglobal(state, failure);
				 lua_pushstring(state, "Document isn't a text document");
				 lua_call(state, 1, 0);					// 1 arg, no result
			 }
		 }
	 }
	 ];
	
	return 0;
}

// schedule(app, secs, callback)
int app_schedule(struct lua_State* state)
{
	double secs = lua_tonumber(state, 2);
	NSString* callback = [NSString stringWithUTF8String:lua_tostring(state, 3)];	// NSString to ensure the memory doesn't go away when we return and pop the stack
	
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (secs*1.0e9));
	dispatch_after(delay, main,
		^{
			// TODO: It would be nice to support calling lua closures, but I'm not
			// quite sure how to do that (e.g. how do we prevent the closure from
			// being GCed?).
			lua_getglobal(state, callback.UTF8String);
			int err = lua_pcall(state, 0, 0, 0);		// 0 args, no result
			if (err)
			{
				if (functionalTestsAreRunning())
				{
					lua_pushvalue(state, -1);
					ftest_failed(state);
				}
				else
				{
					[TranscriptController writeStderr:[NSString stringWithUTF8String:lua_tostring(state, -1)]];
				}
			}
		}
	);

	return 0;
}

// newdoc(app) -> textdoc
int app_newdoc(struct lua_State* state)
{
	NSError* error = nil;
	NSDocument* doc = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"Plain Text, UTF8 Encoded" error:&error];
	ASSERT(doc);
	ASSERT(!error);
	
	[[NSDocumentController sharedDocumentController] addDocument:doc];
	[doc makeWindowControllers];
	[doc showWindows];
		
	pushTextDoc(state, doc);
	
	return 1;
}

// log(app, mesg)
// TODO: might want to stick a log method on all tables (so we get better categories)
int app_log(struct lua_State* state)
{
	const char* mesg = lua_tostring(state, 2);
	LOG_INFO("Mimsy", "%s", mesg);
	return 0;
}

// close(doc)
int doc_close(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	NSDocument* doc = (__bridge NSDocument*) lua_touserdata(state, -1);
	[doc close];		// doesn't ask to save changes
	return 0;
}

// saveas(doc, path, type = nil, success = nil, failure = nil)
int doc_saveas(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	NSDocument* doc = (__bridge NSDocument*) lua_touserdata(state, -1);
	const char* path = lua_tostring(state, 2);
	const char* type = luaL_optstring(state, 3, "Plain Text, UTF8 Encoded");
	const char* success = luaL_optstring(state, 4, NULL);
	const char* failure = luaL_optstring(state, 5, NULL);
	
	NSURL* url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
	[doc saveToURL:url ofType:[NSString stringWithUTF8String:type] forSaveOperation:NSSaveAsOperation completionHandler:
		^(NSError* error)
		{
			if (error && failure)
			{
				NSString* reason = [error localizedFailureReason];
				
				lua_getglobal(state, failure);
				lua_pushstring(state, reason.UTF8String);
				lua_call(state, 1, 0);						// 1 arg, no result
			}
			else if (!error && success)
			{
				lua_getglobal(state, success);
				lua_pushvalue(state, 1);
				lua_call(state, 1, 0);						// 1 arg, no result
			}
		}
	];
	return 0;
}

// data(doc) -> str
int textdoc_data(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	TextDocument* doc = (__bridge TextDocument*) lua_touserdata(state, -1);
	lua_pushstring(state, doc.controller.text.UTF8String);
	return 1;
}
