#import <Foundation/Foundation.h>

@class FindInFilesController;

// One of these is instantiated for each find in files operation.
@interface FindInFiles : NSObject

- (id)init:(FindInFilesController*)controller path:(NSString*)path;

- (void)findAll;

@end
