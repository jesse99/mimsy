#import <Foundation/Foundation.h>

// These are used by the Settings class to (currently) look up user settings
// within the current directory and then the app.
@interface LocalSettings : NSObject

// The file name is used when reporting errors.
- (id)initWithFileName:(NSString*)name;

- (void)addKey:(NSString*)key value:(NSString*)value;

// Returns nil if the key wasn't found. If multiple keys are found
// then an error is written to the transcript window.
- (NSString*)findKey:(NSString*)key;

- (NSArray*)findAllKeys:(NSString*)key;

@end
