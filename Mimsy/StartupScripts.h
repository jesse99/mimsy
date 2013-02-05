#import <Foundation/Foundation.h>

@class TextDocument;

// Used to manage the lua scripts registered at startup. These scripts will
// typically be used to register lua functions to execute for various pre-
// defined Mimsy hooks.
@interface StartupScripts : NSObject

+ (void)setup;

// Called via the Lua app:addhook method. See the Lua Scripting help file
// for details.
+ (void)addHook:(NSString*)hname function:(NSString*)fname;

// These are C entry points to the hooks.
+ (void)invokeApplyStyles:(NSDocument*)doc location:(NSUInteger)loc length:(NSUInteger)len;
+ (void)invokeTextSelectionChanged:(NSDocument*)doc slocation:(NSUInteger)loc slength:(NSUInteger)len;

@end
