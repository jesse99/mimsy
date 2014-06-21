#import <Cocoa/Cocoa.h>
#import "RangeVectorUtils.h"

@class BaseTextController;

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
- (bool)_rangeMatches:(NSRange)range controller:(BaseTextController*)controller;
- (void)_updateComboBox:(NSComboBox*)box with:(NSString*)text;

- (NSString*)_getReplaceTemplate;
- (bool)singleFile;

- (void)_replace:(BaseTextController*)controller regex:(NSRegularExpression*)regex match:(NSTextCheckingResult*)match with:(NSString*)template showSelection:(bool)showSelection;
- (void)_showSelection:(NSRange)range in:(BaseTextController*)controller;

@property (strong) IBOutlet NSComboBox *findComboBox;
@property (strong) IBOutlet NSComboBox *replaceWithComboBox;
@property (strong) IBOutlet NSComboBox *searchWithinComboBox;

@property (strong) IBOutlet NSButton *caseSensitiveCheckBox;
@property (strong) IBOutlet NSButton *matchEntireWordCheckBox;
@property (strong) IBOutlet NSButton *useRegexCheckBox;

@end

NSUInteger replaceAll(BaseFindController* findController, BaseTextController* textController, NSRegularExpression* regex, NSString* template);
