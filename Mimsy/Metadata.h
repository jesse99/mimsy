#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

// This class is used to associate arbitrary bits of information with files and
// directories. There are two usage patterns:
//
// 1) Most metadata is per-user non-critical data. For these extended attributes
// work quite well. For example extended attributes are used to save and restore
// window frames.
//
// 2) Some metadata is user independent and cannot be lost without affecting
// proper operation. An example of this sort of metadata is the background color
// for rich text documents (e.g. RTF). Background color is not a property of
// the text so we need to save it as metadata (and for styles file we can't
// lose the color or syntax highlighting will break).
//
// Because it's user independent it is data that we want to include in the git
// repository and include in the bundle that XCode builds. Unfortunately both
// of those are problematic: git won't include extended attributes and XCode
// won't copy extended attributes into the bundle (even with Preserve HFS Data
// enabled). Both of those are solvable problems (with custom git hooks and custom
// build steps) but extended attributes don't seem like a good fit for data you
// actually care about.
//
// So, in order to have something reliable, core metadata is persisted using
// .<fileName-dataName>.xml files.
@interface Metadata : NSObject

+ (NSError*)writeCriticalDataTo:(MimsyPath*)path named:(NSString*)name with:(id<NSCoding>)object;
+ (id)readCriticalDataFrom:(MimsyPath*)path named:(NSString*)name outError:(NSError**)error;

// These two log errors, but otherwise ignore them.
+ (void)writeNonCriticalDataTo:(MimsyPath*)path named:(NSString*)name with:(id<NSCoding>)object;
+ (id)readNonCriticalDataFrom:(MimsyPath*)path named:(NSString*)name;

@end
