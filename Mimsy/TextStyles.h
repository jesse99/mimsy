#import <Foundation/Foundation.h>

// Contains all the attributes which are applied to text views.
@interface TextStyles : NSObject

+ (void)setup;

// The style used when a style from a styles file is not available.
+ (NSDictionary*)fallbackStyle;

// If name is not present in the styles file then the attributes
// for the "Default" style are returned.
+ (NSDictionary*)attributesForElement:(NSString*)name;

+ (NSColor*)backColor;

@end
