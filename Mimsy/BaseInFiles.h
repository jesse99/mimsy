#import "Glob.h"
#import "MimsyPlugins.h"

@class FindInFilesController;

/// This is common code used by Find in Files and Replace in Files.
@interface BaseInFiles : NSObject

- (id)init:(FindInFilesController*)controller path:(MimsyPath*)path;

- (void)_processRoot;

- (bool)_processPath:(MimsyPath*)path withContents:(NSMutableString*)contents;
- (void)_step1ProcessOpenFiles;
- (void)_step2FindPaths;
- (void)_step3QueuePaths:(NSMutableArray*)paths;

- (bool)_aborted;
- (void)_onFinish;
- (bool)_processMatches:(NSArray*)matches forPath:(MimsyPath*)path withContents:(NSMutableString*)contents;

@property (readonly) MimsyPath* root;
@property (readonly) NSRegularExpression* regex;
@property (readonly) NSString* searchWithin;
@property (readonly) Glob* includeGlobs;

@property int numFilesLeft;

@end
