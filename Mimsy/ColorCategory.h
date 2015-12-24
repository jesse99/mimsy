#import <Foundation/Foundation.h>

@interface NSColor (ColorCategory)

/// Tries colorWithCSS3Name, colorWithVIMName, colorWithHex, and then colorWithDecimal.
/// Like all the colorXXX methods this returns nil for unknown names and the name
/// argument is normalized by lower-casing and removing spaces.
+ (NSColor*)colorWithMimsyName:(NSString*)name;

/// CSS3 extended color names which are the same as SVG 1.0 color names and based on
/// the X11 color names. See http://en.wikipedia.org/wiki/Web_colors#X11_color_names
/// and http://www.w3.org/TR/css3-color/#svg-color
+ (NSColor*)colorWithCSS3Name:(NSString*)name;

/// VIM 7.3 color names. Has most of the CSS3 names and adds quite a few other names.
/// See http://choorucode.com/2011/07/29/vim-chart-of-color-names and
/// http://code.google.com/p/vim/source/browse/runtime/rgb.txt
+ (NSColor*)colorWithVIMName:(NSString*)name;

/// Either an RGB color ('#F00000') or an RGBA color ('#F00000FF').
+ (NSColor*)colorWithHex:(NSString*)value;

/// Either an RGB color ('(255, 0, 0)') or an RGBA color ('(255, 0, 0, 255)').
+ (NSColor*)colorWithDecimal:(NSString*)value;

@end
