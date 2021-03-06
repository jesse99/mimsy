#import "BaseInFiles.h"

@class FindInFilesController;

/// One of these is instantiated for each replace in files operation.
@interface ReplaceInFiles : BaseInFiles

- (id)init:(FindInFilesController*)controller path:(MimsyPath*)path template:(NSString*)template;

- (void)replaceAll;

@end
