#import <Foundation/Foundation.h>

@interface NSScanner (ScannerCategory)

- (BOOL)skip:(unichar)ch;
- (BOOL)scanLiteral:(NSString*)literal;

@end
