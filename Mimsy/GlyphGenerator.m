#import "GlyphGenerator.h"

#import "GlyphsAttribute.h"

@implementation GlyphGenerator

- (void)generateGlyphsForGlyphStorage:(id <NSGlyphStorage>)glyphStorage desiredNumberOfCharacters:(NSUInteger)nChars glyphIndex:(NSUInteger *)glyphIndex characterIndex:(NSUInteger *)charIndex
{
    _destination = glyphStorage;
    [[NSGlyphGenerator sharedGlyphGenerator] generateGlyphsForGlyphStorage:self desiredNumberOfCharacters:nChars glyphIndex:glyphIndex characterIndex:charIndex];
    _destination = nil;
}

// This is not at all well documented but it looks like:
//    glyphs is an array of length unsigned ints that are to be inserted into the NSGlyphStorage
//    glyphIndex is where the glyphs should be inserted
//    charIndex is an index into self.attributedString used to produce the first glyph
//
// Glyphs are not mapped one to one to characters so it's not easy to figure out which characters
// are being inserted.
- (void)insertGlyphs:(const NSGlyph *)inGlyphs length:(NSUInteger)length forStartingGlyphAtIndex:(NSUInteger)glyphIndex characterIndex:(NSUInteger)charIndex
{
    NSGlyph* glyphs = malloc(length*sizeof(NSGlyph));
    memcpy(glyphs, inGlyphs, length*sizeof(NSGlyph));
    
    [self.attributedString enumerateAttribute:GlyphsAttributeName inRange:NSMakeRange(charIndex, length) options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(GlyphsAttribute* attr, NSRange range, BOOL *stop)
    {
        UNUSED(stop);
        
        if (attr)
        {
            NSUInteger offset = range.location - charIndex;
            
            NSUInteger i = 0;
            for (; i < attr.numGlyphs && i < length; ++i)
                glyphs[i + offset] = attr.glyphs[i];

            // Note that Cocoa complains if we don't supply length glyphs.
            for (; i < range.length && i < length; ++i)
                glyphs[i + offset] = NSNullGlyph;
        }
    }];
    
    [_destination insertGlyphs:glyphs length:length forStartingGlyphAtIndex:glyphIndex characterIndex:charIndex];

    free(glyphs);
}

- (void)setIntAttribute:(NSInteger)attributeTag value:(NSInteger)val forGlyphAtIndex:(NSUInteger)glyphIndex
{
    [_destination setIntAttribute:attributeTag value:val forGlyphAtIndex:glyphIndex];
}

- (NSAttributedString *)attributedString {return [_destination attributedString];}

- (NSUInteger)layoutOptions {return [_destination layoutOptions];}

@end
