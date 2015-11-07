#if OLD_EXTENSIONS
@class BaseExtension;

// Used to manage lua scripts and executables that interact with Mimsy via
// proc files.
@interface Extensions : NSObject

+ (void)setup;

// Calls any extensions which have registered to watch the path. Returns true
// if an extension has handled the event and further processing should be
// skipped. Path should be something like "/Volumes/Mimsy/keydown/text-editor/left-arrow/pressed".
+ (bool)invokeBlocking:(NSString*)path;

// Like invokeBlocking except that the call is defered to ensure that the extension can
// use our proc files without deadlocking.
+ (void)invokeNonBlocking:(NSString*)path;

// Returns the name of the extension currently executing.
+ (NSString*)invoked;

// Returns true if an extension is watching path.
+ (bool)watching:(NSString*)path;

+ (void)watch:(NSString*)path extension:(BaseExtension*)extension;

@end
#endif
