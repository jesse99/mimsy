#import <Cocoa/Cocoa.h>

// Used to convert arbitrary text files into an NSString. In general it's not
// possible to know what encoding a particular file uses so various heuristics
// are used to infer the encoding.
@interface Decode : NSObject

- (id)initWithData:(NSData*)data;

// One of text or error will be non-nil.
@property NSMutableString* text;
@property NSString* error;
@property NSStringEncoding encoding;

@end