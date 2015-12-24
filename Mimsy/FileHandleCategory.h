@interface NSFileHandle (Readline)

/// The new line is not included in the result.
- (NSString*)readLine;

/// Returns nil instead of blocking if there is no data.
- (NSData*)availableDataNonBlocking;

@end
