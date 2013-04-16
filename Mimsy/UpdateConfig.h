#import <Foundation/Foundation.h>

// If key is present it is updated to the new value. Otherwise a new preference is
// appended to the file. Returns false and sets outError if there was a problem.
bool updatePref(NSString* path, NSString* key, NSString* value, NSError** outError);