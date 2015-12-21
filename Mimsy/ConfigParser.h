#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

@interface ConfigParserEntry : NSObject
@property NSString* key;
@property NSString* value;		// whitespace will be trimmed from both ends
@property NSUInteger offset;
@property NSUInteger line;
@end

// Used to parse line oriented files where:
// 1) lines that start with a # are comment lines
// 2) lines with just whitespace are ignored
// 3) lines that start with a name and a colon represent key/value pairs
//    the name is anything except whitespace and colon
//    the value is everything after the colon to the end of line character
//    (with whitespace trimmed from the front and back)
// anything else is an error
@interface ConfigParser : NSObject

// If the parse fails nil is returned and error will be set appropiately.
- (id)initWithPath:(MimsyPath*)path outError:(NSError**)error;
- (id)initWithContent:(NSString*)contents outError:(NSError**)error;

// Key/value pairs are returned in the same order they were declared.
// Note that the same key may be used multiple times. Offset will be the
// character index at which the key appeared.
- (NSUInteger)length;
- (id)objectAtIndexedSubscript:(NSUInteger)index;
- (void)enumerate:(void (^)(ConfigParserEntry* entry))block;

// Returns the value for the first key or nil if the key was not present.
-(NSString*)valueForKey:(NSString*)key;

@end
