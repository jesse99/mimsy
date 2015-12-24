#import <Foundation/Foundation.h>

extern NSString* GlyphsAttributeName;

/// Contains a sequence of glyphs used instead of the normal glyphs for a range of text.
@interface GlyphsAttribute : NSObject

/// See addMapping for an explanation of these arguments.
- (id)initWithStyle:(NSDictionary*)style chars:(NSString*)chars repeat:(bool)repeat;

- (NSUInteger)numGlyphs;

- (CGGlyph*)glyphs;

- (bool)repeat;

@end
