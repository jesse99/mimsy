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
- (void)_settingsChanged:(NSNotification*)notification;

- (NSRegularExpression*)_getRegex;
- (bool)_rangeMatches:(NSRange)range;
- (void)_updateComboBox:(NSComboBox*)box with:(NSString*)text;

- (NSString*)_getReplaceTemplate;

@property (strong) IBOutlet NSComboBox *findComboBox;
@property (strong) IBOutlet NSComboBox *replaceWithComboBox;
@property (strong) IBOutlet NSComboBox *searchWithinComboBox;

@property (strong) IBOutlet NSButton *caseSensitiveCheckBox;
@property (strong) IBOutlet NSButton *matchEntireWordCheckBox;
@property (strong) IBOutlet NSButton *useRegexCheckBox;

@end
