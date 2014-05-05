// Used to highlight and select matched braces.
#import <Foundation/Foundation.h>

// Returns a range by extending the selection left until an open brace is found
// which is not closed within the range. Then the range is extended right until
// the new brace is closed. The returned range will start and end with braces
// or have a zero length if it could not be balanced.
NSRange balance(NSString* text, NSRange range);

// indexIsCloseBrace will be set according to whether the character at index
// is a closing brace. foundOpenBrace will be set if a corresponding open brace
// was found. If foundOpenBrace is true the open brace's index is returned.
NSUInteger balanceLeft(NSString* text, NSUInteger index, bool* indexIsCloseBrace, bool* foundOpenBrace);
