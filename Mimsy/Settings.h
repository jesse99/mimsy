#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

@class Settings;

/// Preference data is loaded from settings files and forms a chain where the most specific
/// settings can override or extend earlier settings. Each settings file is represented by a
/// SettingsContext. The chain consists of the app (app.mimsy), directory windows (.mimsy.rtf),
/// and language files (e.g. C.mimsy).
@protocol SettingsContext

/// Will be nil for the root which is either the app or, transiently,
/// a plugin.
- (nullable id<SettingsContext>)parent;

- (nullable Settings*)layeredSettings;

@end

extern id<SettingsContext> __nullable activeContext;

/// Preferences loaded from a SettingsContext.
@interface Settings : NSObject <MimsySettings>

/// Name is used for error reporting.
- (nonnull Settings*)init:(nonnull NSString*)name context:(nonnull id<SettingsContext>)context;

- (nonnull id<SettingsContext>)context;

- (void)addKey:(nonnull NSString*)key value:(nonnull NSString*)value;

- (bool)hasKey:(nonnull NSString*)name;

- (nonnull NSArray*)getKeys;

/// These are used to access single values which may be overridden.
- (BOOL)boolValue:(nonnull NSString*)name missing:(BOOL)value;

- (int)intValue:(nonnull NSString*)name missing:(int)value;

- (unsigned int)uintValue:(nonnull NSString*)name missing:(unsigned int)value;

- (nonnull NSString*)stringValue:(nonnull NSString*)name missing:(nonnull NSString*)value;

//// These are used to access keys which may have multiple values. Contexts
// may extend these with new values.
- (nonnull NSArray*)stringValues:(nonnull NSString*)name;

/// This is nice to use in place of stringValues whenever parsing
/// is involved because when emitting warnings the fileName can
/// be included.
- (void)enumerate:(nonnull NSString*) key with:(void (^ __nonnull)(NSString* __nonnull fileName, NSString* __nonnull value))block;

- (NSUInteger)checksum;

@end

