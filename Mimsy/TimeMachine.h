#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

@interface TimeMachine : NSObject

+(void)appendContextMenu:(NSMenu*)menu;

+ (void)openLatest;
+ (void)openFiles;

+(bool)isSnapshotFile:(MimsyPath*)path;
+(NSString*)getSnapshotLabel:(MimsyPath*)path;

@end
