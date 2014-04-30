#import <Foundation/Foundation.h>

@interface TimeMachine : NSObject

+(void)appendContextMenu:(NSMenu*)menu;

+(bool)isSnapshotFile:(NSString*)path;
+(NSString*)getSnapshotLabel:(NSString*)path;

@end
