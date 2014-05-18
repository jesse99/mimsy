#import <Cocoa/Cocoa.h>

// Base class for find and find in files.
@interface BaseFindController : NSWindowController

// Use these instead of changing the combo boxes directly.
@property NSString* findText;
@property NSString* replaceText;
@property NSString* searchWithinText;

- (void)_enableButtons;
- (bool)_findEnabled;
- (bool)_replaceEnabled;

- (NSRegularExpression*)_getRegex;

@property (strong) IBOutlet NSComboBox *findComboBox;
@property (strong) IBOutlet NSComboBox *replaceWithComboBox;
@property (strong) IBOutlet NSComboBox *searchWithinComboBox;

@property (strong) IBOutlet NSButton *caseSensitiveCheckBox;
@property (strong) IBOutlet NSButton *matchEntireWordCheckBox;
@property (strong) IBOutlet NSButton *useRegexCheckBox;

@end
