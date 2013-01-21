#import <Foundation/Foundation.h>

struct lua_State;

// These are the methods we make available to lua scripting code (FunctionalTest
// also provides a few methods in the ftest global). All of the methods are provided
// in tables which contain a target entry whose value represents an NSObject pointer
// (e.g. NSApplication*, NSDocument*, etc).
//
// See the XXX help file for information about the methods.

void initMethods(struct lua_State* state);

// ---- App --------------------------------------------------------------------
int app_openfile(struct lua_State* state);
int app_log(struct lua_State* state);

// ---- Document ---------------------------------------------------------------
int doc_close(struct lua_State* state);
int doc_saveas(struct lua_State* state);

// ---- Text Document ----------------------------------------------------------
int textdoc_data(struct lua_State* state);
