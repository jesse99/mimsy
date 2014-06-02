#import <Foundation/Foundation.h>

@class FindInFilesController;

@interface FindInFiles : NSObject

- (id)init:(FindInFilesController*)controller path:(NSString*)path;

- (void)findAll;

@end
