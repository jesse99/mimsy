#import <Foundation/Foundation.h>

@interface NSData (NSDataCategory)

+ (NSData*)dataByBase64DecodingString:(NSString*)decode;

- (NSString*)base64EncodedString;

- (NSRange)rangeOfData:(NSData*)needle;

@end
