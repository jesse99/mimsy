@interface NSString (StringCategory)

+ (NSString*)stringWithN:(NSUInteger)count instancesOf:(NSString*)token;

- (bool)startsWith:(NSString*)needle;
- (bool)endsWith:(NSString*)needle;
- (bool)contains:(NSString*)needle;

- (bool)containsChar:(unichar)ch;
- (NSUInteger)indexOfLastChar:(unichar)needle;

/// Like componentsSeparatedByString: except that empty strings are not returned.
- (NSArray*)splitByString:(NSString*)separator;

/// Like componentsSeparatedByString: except that empty strings are not returned.
- (NSArray*)splitByChars:(NSCharacterSet*)chars;

/// Capitilizes the first character in the string.
- (NSString*)titleCase;

/// Returns a new string with each character mapped using the block.
- (NSString*)map:(unichar (^)(unichar ch))block;

/// Returns "baz • bar • foo" for "/foo/bar/baz".
- (NSString*)reversePath;

/// Returns a new string with all characters in chars replaced with with.
- (NSString*)replaceCharacters:(NSString*)chars with:(NSString*)with;

@end
