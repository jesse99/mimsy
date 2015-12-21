#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

// If key is present it is updated to the new value. Otherwise a new preference is
// appended to the file. Returns false and sets outError if there was a problem.
bool updatePref(MimsyPath* path, NSString* key, NSString* value, NSError** outError);