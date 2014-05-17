#import <Cocoa/Cocoa.h>

@class Glob;

// This is the controller for the windows which display the contents of a directory.
// These windows work a bit like project windows in IDEs.
@interface DirectoryController : NSWindowController

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

// Use the Settings class instead of this.
- (NSString*)findSetting:(NSString*)name;

- (NSDictionary*)getDirAttrs:(NSString*)path;
- (NSDictionary*)getFileAttrs:(NSString*)path;
- (NSDictionary*)getSizeAttrs;

@property NSString* path;
@property Glob* ignores;
@property NSMutableArray* targetGlobs;
@property NSMutableArray* flags;
@property Glob* preferredPaths;
@property Glob* ignoredPaths;
@property NSArray* searchIn;

@property (weak) IBOutlet NSOutlineView* table;
@property (weak) IBOutlet NSPopUpButton* targetsMenu;
@property (weak) IBOutlet NSToolbarItem* buildButton;
@property (weak) IBOutlet NSToolbarItem* cancelButton;

@end
