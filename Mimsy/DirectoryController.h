#import <Cocoa/Cocoa.h>
#import "MimsyPlugins.h"
#import "Settings.h"

@class Glob;

/// This is the controller for the windows which display the contents of a directory.
/// These windows work a bit like project windows in IDEs.
@interface DirectoryController : NSWindowController<SettingsContext, MimsyProject>

+ (DirectoryController* _Nullable)getCurrentController;
+ (DirectoryController* _Nullable)getController:(MimsyPath* __nonnull)path;
+ (DirectoryController* __nonnull)open:(MimsyPath* __nonnull)path;
+ (void)enumerate:(void (^ __nonnull)(DirectoryController* __nonnull controller))block;

- (bool)shouldOpen:(MimsyPath* __nonnull)path;
- (void)doubleClicked:(id __nonnull)sender;
- (void)deleted:(id __nonnull)sender;
- (IBAction)targetChanged:(id __nonnull)sender;
- (bool)canBuild;
- (NSString* _Nullable)buildTargetName;
- (void)buildTarget:(id __nonnull)sender;
- (void)saveBuildFlags;

- (NSDictionary* __nonnull)getDirAttrs:(NSString* __nonnull)name;
- (NSDictionary* __nonnull)getFileAttrs:(NSString* __nonnull)name;
- (NSDictionary* __nonnull)getSizeAttrs;

- (id<SettingsContext> __nonnull)parent;
- (Settings* __nonnull)layeredSettings;

@property Glob* __nonnull ignores;
@property Glob* __nonnull dontIgnores;
@property NSMutableArray* __nonnull targetGlobs;
@property NSMutableArray* __nonnull flags;
@property Glob* __nonnull preferredPaths;
@property Glob* __nonnull ignoredPaths;

@property (nonatomic, readonly, strong) MimsyPath* __nonnull path;
@property (nonatomic, readonly, strong) id<MimsySettings> __nonnull settings;
@property (weak) IBOutlet NSOutlineView* _Nullable table;
@property (weak) IBOutlet NSPopUpButton* _Nullable targetsMenu;
@property (weak) IBOutlet NSToolbarItem* _Nullable buildButton;
@property (weak) IBOutlet NSToolbarItem* _Nullable cancelButton;

@end
