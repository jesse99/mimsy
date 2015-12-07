#import <Cocoa/Cocoa.h>
#import "MimsyPlugins.h"
#import "Settings.h"

@class Glob;

// This is the controller for the windows which display the contents of a directory.
// These windows work a bit like project windows in IDEs.
@interface DirectoryController : NSWindowController<SettingsContext, MimsyProject>

+ (DirectoryController*)getCurrentController;
+ (DirectoryController*)getController:(NSString*)path;
+ (DirectoryController*)open:(NSString*)path;
+ (void)enumerate:(void (^)(DirectoryController* controller))block;

- (bool)shouldOpen:(NSString*)path;
- (void)doubleClicked:(id)sender;
- (void)deleted:(id)sender;
- (IBAction)targetChanged:(id)sender;
- (bool)canBuild;
- (NSString*)buildTargetName;
- (void)buildTarget:(id)sender;
- (void)saveBuildFlags;

- (NSDictionary*)getDirAttrs:(NSString*)path;
- (NSDictionary*)getFileAttrs:(NSString*)path;
- (NSDictionary*)getSizeAttrs;

- (id<SettingsContext>)parent;
- (Settings*)settings;

@property NSString* thePath;
@property Glob* ignores;
@property Glob* dontIgnores;
@property NSMutableArray* targetGlobs;
@property NSMutableArray* flags;
@property Glob* preferredPaths;
@property Glob* ignoredPaths;

@property (weak) IBOutlet NSOutlineView* table;
@property (weak) IBOutlet NSPopUpButton* targetsMenu;
@property (weak) IBOutlet NSToolbarItem* buildButton;
@property (weak) IBOutlet NSToolbarItem* cancelButton;

@end
