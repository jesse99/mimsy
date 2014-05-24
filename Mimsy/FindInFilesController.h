#import "BaseFindController.h"

@interface FindInFilesController : BaseFindController

+ (void)show;
+ (FindInFilesController*)getController;

- (IBAction)findAll:(id)sender;
- (IBAction)replaceAll:(id)sender;
- (IBAction)reset:(id)sender;
- (IBAction)addDirectory:(id)sender;

- (void)_enableButtons;
- (void)controlTextDidChange:(NSNotification *)obj;

@property (strong) IBOutlet NSPopUpButton *directoryMenu;
@property (strong) IBOutlet NSComboBox *includedGlobsComboBox;
@property (strong) IBOutlet NSComboBox *excludedGlobsComboBox;

@property (strong) IBOutlet NSButton *addDirectoryButton;
@property (strong) IBOutlet NSButton *resetButton;
@property (strong) IBOutlet NSButton *findAllButton;
@property (strong) IBOutlet NSButton *replaceAllButton;

@end
