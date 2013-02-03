#import <Foundation/Foundation.h>

// Contains all the attributes which are applied to text views.
@interface TextStyles : NSObject

// Path should be a full path to a styles rtf file.
- (id)initWithPath:(NSString*)path;

// The style used when a style from a styles file is not available.
+ (NSDictionary*)fallbackStyle;

// If name is not present in the styles file then the attributes
// for the "Normal" style are returned.
- (NSDictionary*)attributesForElement:(NSString*)name;

// Like attributesForElement except that nil is returned if name
// is not present.
- (NSDictionary*)attributesForOnlyElement:(NSString*)name;

- (NSColor*)backColor;

@property (readonly) NSString* path;

@end
