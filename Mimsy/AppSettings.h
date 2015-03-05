#import <Foundation/Foundation.h>

// Preferences loaded from app.mimsy and the current directory's
//.mimsy.rtf (if present) and the current language file (if present).
@interface AppSettings : NSObject

+ (bool)boolValue:(NSString*)name missing:(bool)value;

+ (int)intValue:(NSString*)name missing:(int)value;

+ (unsigned int)uintValue:(NSString*)name missing:(unsigned int)value;

+ (NSString*)stringValue:(NSString*)name missing:(NSString*)value;

+ (NSArray*)stringValues:(NSString*)name;

// This is nice to use in place of stringValues whenever parsing
// is involved because when emitting warnings the fileName can
// be included.
+ (void)enumerate:(NSString*) key with:(void (^)(NSString* fileName, NSString* value))block;

+ (NSArray*)getKeys;

// This is used to distinguish between app settings and directory/
// language settings.
+ (void)registerSetting:(NSString*)name;
+ (bool)isSetting:(NSString*)name;
+ (id)updateAppSettings;

@end
