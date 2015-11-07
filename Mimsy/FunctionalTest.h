#if OLD_EXTENSIONS
#import <Foundation/Foundation.h>

struct lua_State;

// Adds a Test menu to allow functional tests to be run (if MIMSY_FTEST is set).
void initFunctionalTests(void);

void addFunctionalTestHelpContext(NSMutableArray* result, NSString* path);

void runFunctionalTest(NSString* path);
void runFunctionalTests(void);

bool functionalTestsAreRunning(void);
void recordFunctionalError(NSString* mesg);

int ftest_failed(struct lua_State* state);

void updateInstanceCount(NSString* name, NSInteger delta);
#endif