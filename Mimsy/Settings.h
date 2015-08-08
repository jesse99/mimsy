#import <Foundation/Foundation.h>

@class Settings;

// Preference data is loaded from settings files and forms a chain where the most specific
// settings can override or extend earlier settings. Each settings file is represented by a
// SettingsContext. The chain consists of the app (app.mimsy), directory windows (.mimsy.rtf),
// and language files (e.g. C.mimsy).
@protocol SettingsContext

// Will be nil for the app.
- (id<SettingsContext>)parent;

- (Settings*)settings;

@end

// Preferences loaded from a SettingsContext.
@interface Settings : NSObject

// Name is used for error reporting.
- (Settings*)init:(NSString*)name context:(id<SettingsContext>)context;

- (id<SettingsContext>)context;

- (void)addKey:(NSString*)key value:(NSString*)value;

- (bool)hasKey:(NSString*)name;

- (NSArray*)getKeys;

// These are used to access single values which may be overridden.
- (bool)boolValue:(NSString*)name missing:(bool)value;

- (int)intValue:(NSString*)name missing:(int)value;

- (unsigned int)uintValue:(NSString*)name missing:(unsigned int)value;

- (NSString*)stringValue:(NSString*)name missing:(NSString*)value;

// These are used to access keys which may have multiple values. Contexts
// may extend these with new values.
- (NSArray*)stringValues:(NSString*)name;

// This is nice to use in place of stringValues whenever parsing
// is involved because when emitting warnings the fileName can
// be included.
- (void)enumerate:(NSString*) key with:(void (^)(NSString* fileName, NSString* value))block;

@end
