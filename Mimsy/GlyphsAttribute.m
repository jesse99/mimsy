#import "GlyphsAttribute.h"

NSString* GlyphsAttributeName = @"mimsy-glyphs";

@implementation GlyphsAttribute
{
    NSUInteger _count;
    CGGlyph* _glyphs;
    bool _repeat;
}

- (id)initWithStyle:(NSDictionary*)style chars:(NSString*)text repeat:(bool)repeat
{
    NSTextStorage *storage = [[NSTextStorage alloc] initWithString:text];
    NSTextContainer *container = [NSTextContainer new];
    NSLayoutManager *layout = [NSLayoutManager new];
    [layout addTextContainer:container];
    [storage addLayoutManager:layout];
    [storage addAttributes:style range:NSMakeRange(0, text.length)];
    
    NSUInteger capacity = 10*text.length;       // can be more glyphs than chars so we'll allocate way more than we need
    _glyphs = malloc(capacity*sizeof(CGGlyph));
    
    _count = [layout getGlyphsInRange:NSMakeRange(0, capacity) glyphs:_glyphs properties:nil characterIndexes:NULL bidiLevels:NULL];
    _repeat = repeat;
    
    return self;
}

- (void)dealloc
{
    free(_glyphs);
}

- (NSUInteger)numGlyphs
{
    return _count;
}

- (CGGlyph*)glyphs
{
    return _glyphs;
}

- (bool)repeat
{
    return _repeat;
}

@end
