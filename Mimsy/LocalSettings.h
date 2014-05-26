#import <Foundation/Foundation.h>

// These are used by the AppSettings class to look up user settings
// within the current language, current directory and then the app.
@interface LocalSettings : NSObject

// The file name is used when reporting errors.
- (id)initWithFileName:(NSString*)name;

- (id)copy;
+ (bool)is:(LocalSettings*)lhs equalTo:(LocalSettings*)rhs;

- (void)addKey:(NSString*)key value:(NSString*)value;

// Returns nil if the key wasn't found. If multiple keys are found
// then an error is written to the transcript window.
- (NSString*)findValueForKey:(NSString*)key;

- (NSArray*)findValuesForKey:(NSString*)key;

- (NSArray*)getKeys;

- (void)enumerate:(NSString*)key with:(void (^)(NSString* fileName, NSString* value))block;
- (void)enumerateAll:(void (^)(NSString* key, NSString* value))block;

@end
