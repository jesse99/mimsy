@class ProcFileSystem;

// This is used to generate the "app-Special Keys.rtf" help file. It uses the
// built-in-special-keys.json file as well as proc files written by extensions.
@interface SpecialKeys : NSObject

+ (void)setup:(ProcFileSystem*)fs;

@end
