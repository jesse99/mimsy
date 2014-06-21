#import <Foundation/Foundation.h>

@interface TimeMachine : NSObject

+(void)appendContextMenu:(NSMenu*)menu;

+ (void)openLatest;
+ (void)openFiles;

+(bool)isSnapshotFile:(NSString*)path;
+(NSString*)getSnapshotLabel:(NSString*)path;

@end
