#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

@class ConditionalGlob, ConfigParser, RegexStyler;

/// Encapsulates the information from a language file.
@interface Language : NSObject <MimsyLanguage>

- (id _Nullable)initWithParser:(ConfigParser* _Nonnull)parser outError:(NSError* _Nonnull* _Nonnull)error;

+ (bool)parseHelp:(NSString* _Nonnull)value help:(NSMutableArray* _Nonnull)help;

- (BOOL)matches:(MimsyPath* __nonnull)file;

- (NSArray<NSString*>* __nonnull)getPatterns:(NSString* __nonnull)element;

// ---- Required Elements -----------------------------------------

/// The name of the language, e.g. "c", "python", etc.
@property (nonatomic, readonly, copy) NSString * __nonnull name;

/// The object used to associate files with this particular language.
@property (nonatomic, readonly, copy) ConditionalGlob * __nonnull glob;

/// Sequence of tool names.
@property (readonly) NSArray* _Nonnull shebangs;

/// The object used to compute the styles associated with a document.
@property (readonly) RegexStyler* _Nonnull styler;

// ---- Optional Elements (may be nil) -----------------------------

/// The string indicating the start of a line comment. Used for things
/// like commenting out selections.
@property (nonatomic, readonly, copy) NSString * __nullable lineComment;

/// Used to match words when double clicking.
@property (nonatomic, readonly, strong) NSRegularExpression * __nullable word;
@property (nonatomic, readonly, strong) NSRegularExpression * __nullable number;

// ---- Settings ---------------------------------------------------
- (NSArray* _Nonnull)settingKeys;
- (NSArray* _Nonnull)settingValues;

@end
