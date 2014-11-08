#import <Foundation/Foundation.h>

// Used to open files with Mimsy where posible and the Finder otherwise. Note that OpenSelection can be
// used to open file names or paths relative to the current project.
@interface OpenFile : NSObject

+ (bool)shouldOpenFiles:(NSUInteger)numFiles;
+ (void)openPath:(NSString*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width;
+ (void)openPath:(NSString*)path withRange:(NSRange)range;

// Note that this is relatively slow.
+ (bool)tryOpenPath:(NSString*)path atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width;

@end
