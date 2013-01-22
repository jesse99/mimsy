#import <Foundation/Foundation.h>

// Adds a Test menu to allow functional tests to be run (if MIMSY_FTEST is set).
void initFunctionalTests(void);

void runFunctionalTest(NSString* path);
void runFunctionalTests(void);

bool functionalTestsAreRunning(void);
void recordFunctionalError(NSString* mesg);