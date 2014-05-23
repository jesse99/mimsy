// Used to highlight and select matched braces.
#import <Foundation/Foundation.h>

typedef bool (^IsBrace)(NSUInteger index);

// Returns a range by extending the selection left until an open brace is found
// which is not closed within the range. Then the range is extended right until
// the new brace is closed. The returned range will start and end with braces
// or have a zero length if it could not be balanced.
NSRange balance(NSString* text, NSRange range, IsBrace isOpenBrace, IsBrace isCloseBrace);

// Sets indexIsOpenBrace or indexIsCloseBrace if the character at index is a brace.
// If so, and the corresponding close or open brace is found, then foundOtherBrace
// is set and that brace's index is returned.
NSUInteger tryBalance(NSString* text, NSUInteger index, bool* indexIsOpenBrace, bool* indexIsCloseBrace, bool* foundOtherBrace, IsBrace isOpenBrace, IsBrace isCloseBrace);

// Like tryBalance except that it takes a one character range and attempts to
// balance if the range contains a brace. If succussful the returned range
// will be non-empty.
NSRange tryBalanceRange(NSString* text, NSRange range, IsBrace isOpenBrace, IsBrace isCloseBrace);


