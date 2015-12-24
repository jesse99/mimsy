/// This is used to generate the "app-Special Keys.rtf" help file. It uses the
/// built-in-special-keys.json file as well as information provided by plugins.
@interface SpecialKeys : NSObject

+ (void)setup;
+ (void)updated;

+ (void)addPlugin:(NSString*)plugin context:(NSString*)context key:(NSString*)name description:(NSString*)description;

+ (void)removePlugin:(NSString*)plugin context:(NSString*)context;

@end
