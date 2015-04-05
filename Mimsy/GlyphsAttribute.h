#import <Foundation/Foundation.h>

extern NSString* GlyphsAttributeName;

// Contains a sequence of glyphs used instead of the normal glyphs for a range of text.
@interface GlyphsAttribute : NSObject

- (id)initWithStyle:(NSDictionary*)style chars:(NSString*)chars;

- (NSUInteger)numGlyphs;

- (NSGlyph*)glyphs;

@end
