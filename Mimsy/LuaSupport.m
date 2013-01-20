#import "LuaSupport.h"

#include <lauxlib.h>

#import "Logger.h"
#import "TextController.h"
#import "TextDocument.h"

static void pushTextDoc(struct lua_State* state, NSDocument* doc)
{
	luaL_Reg methods[] =
	{
		{"data", textdoc_data},
		{"close", doc_close},
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
		{"openfile", app_openfile},
		{"log", app_log},
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

// log(app, mesg)
int app_log(struct lua_State* state)
{
	const char* mesg = lua_tostring(state, 2);
	LOG_INFO("Mimsy", "%s", mesg);
	return 0;
}

// data(doc) -> str
int textdoc_data(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	TextDocument* doc = (__bridge TextDocument*) lua_touserdata(state, -1);
	LOG_INFO("Mimsy", "doc = %s", STR(doc));
	LOG_INFO("Mimsy", "data = %s", doc.controller.text.UTF8String);
	lua_pushstring(state, doc.controller.text.UTF8String);
	return 1;
}

// close(doc)
int doc_close(struct lua_State* state)
{
	lua_getfield(state, 1, "target");
	NSDocument* doc = (__bridge NSDocument*) lua_touserdata(state, -1);
	[doc close];		// doesn't ask to save changes
	return 0;
}
