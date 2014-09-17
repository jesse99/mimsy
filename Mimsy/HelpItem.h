#import <Foundation/Foundation.h>

// These are used to populate the Help menu. They are derived from
// the files within the help directory and from ContextHelp app,
// directory, and language settings.
@interface HelpItem : NSObject

// Path to a file in the help directory. The file name should be
// formatted as context names terminated by dashes followed by
// a menu item title.
- (id)initFromPath:(NSString*)path err:(NSError**)error;

// fileName is the setting file and used for error reporting. value
// is formated as {context names separated by dashes}[title]url.
- (id)initFromSetting:(NSString*)fileName value:(NSString*)value err:(NSError**)error;

- (bool)matchesContext:(NSString*)context;

// The text to use for the help menu item.
- (NSString*)title;

// The URL to open when the user selects the menu item.
- (NSURL*)url;

@end
