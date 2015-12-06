#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

@class Settings;

// Preference data is loaded from settings files and forms a chain where the most specific
// settings can override or extend earlier settings. Each settings file is represented by a
// SettingsContext. The chain consists of the app (app.mimsy), directory windows (.mimsy.rtf),
// and language files (e.g. C.mimsy).
@protocol SettingsContext

// Will be nil for the app.
- (id<SettingsContext> __nullable)parent;

- (Settings* __nullable)settings;

@end

extern id<SettingsContext> __nullable activeContext;

// Preferences loaded from a SettingsContext.
@interface Settings : NSObject <MimsySettings>

// Name is used for error reporting.
- (Settings* __nonnull)init:(NSString* __nonnull)name context:(id<SettingsContext> __nonnull)context;

- (id<SettingsContext> __nonnull)context;

- (void)addKey:(NSString* __nonnull)key value:(NSString* __nonnull)value;

- (bool)hasKey:(NSString* __nonnull)name;

- (NSArray* __nonnull)getKeys;

// These are used to access single values which may be overridden.
- (BOOL)boolValue:(NSString* __nonnull)name missing:(BOOL)value;

- (int)intValue:(NSString* __nonnull)name missing:(int)value;

- (unsigned int)uintValue:(NSString* __nonnull)name missing:(unsigned int)value;

- (NSString* __nonnull)stringValue:(NSString* __nonnull)name missing:(NSString* __nonnull)value;

// These are used to access keys which may have multiple values. Contexts
// may extend these with new values.
- (NSArray* __nonnull)stringValues:(NSString* __nonnull)name;

// This is nice to use in place of stringValues whenever parsing
// is involved because when emitting warnings the fileName can
// be included.
- (void)enumerate:(NSString* __nonnull) key with:(void (^ __nonnull)(NSString* __nonnull fileName, NSString* __nonnull value))block;

@end

