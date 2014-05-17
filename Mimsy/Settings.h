#import <Foundation/Foundation.h>

@class ConfigParser;
@class DirectoryController;

// Preferences loaded from app-settings.mimsy and project-settings.mimsy
// (if present).
@interface Settings : NSObject

+ (bool)boolValue:(NSString*)name missing:(bool)value;

+ (NSString*)stringValue:(NSString*)name missing:(NSString*)value;

@end
