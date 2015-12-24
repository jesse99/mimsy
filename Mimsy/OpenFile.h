#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

@class TextController;

typedef void (^CompletionBlock)(TextController* controller);

//// Used to open files with Mimsy where posible and the Finder otherwise. Note that OpenSelection can be
// used to open file names or paths relative to the current project.
@interface OpenFile : NSObject

/// Takes either a relative path or a file name and returns either a full path
/// with the given root or nil.
/// 1. If the path is an absolute path then return it.
/// 2. If the path is relative and ends a path within root then return its absolute path.
/// 3. If the path is a file name then return all absolute paths within the root with that name.
+ (NSArray<MimsyPath*>*)resolvePath:(MimsyPath*)path rootedAt:(MimsyPath*)root;

+ (bool)shouldOpenFiles:(NSUInteger)numFiles;

/// Note that these are asynchronous operations. If the tab width is unknown use 1.
+ (void)openPath:(MimsyPath*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width;
+ (void)openPath:(MimsyPath*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width completed:(CompletionBlock)completed;
+ (void)openPath:(MimsyPath*)path withRange:(NSRange)range;

/// Note that this is relatively slow.
+ (bool)tryOpenPath:(MimsyPath*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width;

@end
