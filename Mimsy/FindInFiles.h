#import "BaseInFiles.h"

/// One of these is instantiated for each find in files operation.
@interface FindInFiles : BaseInFiles

- (id)init:(FindInFilesController*)controller path:(MimsyPath*)path;

- (void)findAll;

@end
