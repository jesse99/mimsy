#import <Cocoa/Cocoa.h>

@interface GlyphGenerator : NSGlyphGenerator <NSGlyphStorage>
{
    id <NSGlyphStorage> _destination; // the original glyph generation requester
}
@end