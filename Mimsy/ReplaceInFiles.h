#import <Foundation/Foundation.h>

@class FindInFilesController;

// One of these is instantiated for each replace in files operation.
@interface ReplaceInFiles : NSObject

- (id)init:(FindInFilesController*)controller path:(NSString*)path template:(NSString*)template;

- (void)replaceAll;

@end
