#import <Foundation/Foundation.h>

@class InstallFiles;

@interface Plugins : NSObject

+ (void)startLoading;
+ (void)installFiles:(InstallFiles*)installer;
+ (void)refreshSettings;
+ (void)finishLoading;
+ (void)teardown;

@end
