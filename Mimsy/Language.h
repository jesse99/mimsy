#import <Foundation/Foundation.h>

@class ConditionalGlob, ConfigParser, LocalSettings, RegexStyler;

// Encapsulates the information from a language file.
@interface Language : NSObject

- (id)initWithParser:(ConfigParser*)parser outError:(NSError**)error;

+ (bool)parseHelp:(NSString*)value help:(NSMutableArray*)help;

// ---- Required Elements -----------------------------------------

// The name of the language, e.g. "c", "python", etc.
@property (readonly) NSString* name;

// The object used to associate files with this particular language.
@property (readonly) ConditionalGlob* glob;

// Sequence of tool names.
@property (readonly) NSArray* shebangs;

// The object used to compute the styles associated with a document.
@property (readonly) RegexStyler* styler;

// ---- Optional Elements (may be nil) -----------------------------

// The string indicating the start of a line comment. Used for things
// like commenting out selections.
@property (readonly) NSString* lineComment;

// Used to match words when double clicking.
@property (readonly) NSRegularExpression* word;
@property (readonly) NSRegularExpression* number;

// ---- Settings ---------------------------------------------------
- (NSArray*)settingKeys;
- (NSArray*)settingValues;

@end
