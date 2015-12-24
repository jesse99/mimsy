#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

/// This is used with Mimsy settings files formatted as rtf documents.
/// In addition to providing the values for keys it provides the text
/// attributes used with the key.
@interface TextStyles : NSObject

/// Path should be a full path to a styles rtf file.
- (id)initWithPath:(MimsyPath*)path expectBackColor:(bool)expectBackColor;

/// If name is not present in the styles file then the attributes
/// for the "normal" style are returned.
- (NSDictionary*)attributesForElement:(NSString*)name;

/// Like attributesForElement except that nil is returned if name
/// is not present.
- (NSDictionary*)attributesForOnlyElement:(NSString*)name;

- (NSColor*)backColor;

/// Returns nil if the key isn't present.
- (NSString*)valueForKey:(NSString*)key;

@property (readonly) MimsyPath* path;

@end
