#import "BaseFindController.h"

@interface FindController : BaseFindController

+ (void)show;
+ (FindController*)getController;

- (IBAction)find:(id)sender;
- (IBAction)findPrevious:(id)sender;
- (IBAction)replace:(id)sender;
- (IBAction)replaceAll:(id)sender;
- (IBAction)replaceAndFind:(id)sender;

- (void)_enableButtons;
- (void)controlTextDidChange:(NSNotification *)obj;

@property (strong) IBOutlet NSButton *replaceAllButton;
@property (strong) IBOutlet NSButton *replaceButton;
@property (strong) IBOutlet NSButton *replaceAndFindButton;
@property (strong) IBOutlet NSButton *findButton;


@end
