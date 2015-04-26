#import <Foundation/Foundation.h>

extern NSString* GlyphsAttributeName;

// Contains a sequence of glyphs used instead of the normal glyphs for a range of text.
@interface GlyphsAttribute : NSObject

- (id)initWithStyle:(NSDictionary*)style chars:(NSString*)chars repeat:(bool)repeat;

- (NSUInteger)numGlyphs;

- (NSGlyph*)glyphs;

- (bool)repeat;

@end
