@class BaseExtension;

// Used to manage lua scripts and executables that interact with Mimsy via
// proc files.
@interface Extensions : NSObject

+ (void)setup;

// Calls any extensions which have registered to watch the path. Returns true
// if an extension has handled the event and further processing should be
// skipped. Path should be something like "/Volumes/Mimsy/keydown/text-editor/left-arrow/pressed".
+ (bool)invoke:(NSString*)path;

// Returns true if an extension is watching path.
+ (bool)watching:(NSString*)path;

+ (void)watch:(NSString*)path extension:(BaseExtension*)extension;

@end
