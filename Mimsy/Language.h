#import <Foundation/Foundation.h>

@class ConditionalGlob, ConfigParser, RegexStyler;

// Encapsulates the information from a language file.
@interface Language : NSObject

- (id)initWithParser:(ConfigParser*)parser outError:(NSError**)error;

// ---- Required Elements -----------------------------------------

// The name of the language, e.g. "c", "python", etc.
@property (readonly) NSString* name;

// The object used to associated files with this particular language.
@property (readonly) ConditionalGlob* glob;

// The object used to compute the styles associated with a document.
@property (readonly) RegexStyler* styler;

// ---- Optional Elements (may be nil) -----------------------------

// The string indicating the start of a line comment. Used for things
// like commenting out selections.
@property (readonly) NSString* lineComment;

// Sequence of menu item titles and url pairs.
@property (readonly) NSArray* help;

@end
