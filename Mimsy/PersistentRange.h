#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

@class PersistentRange, BaseTextController, TranscriptController;
typedef void (^RangeBlock)(PersistentRange* pr);

/// Represents a range into a text window that is kept up to date as the
/// text changes. Useful for things like bookmarks or find matches. Note
/// that these work regardless of whether the associated window is open
/// (or re-opened).
@interface PersistentRange : NSObject

/// Callback will be called if the location of the range changes.
- (id)init:(MimsyPath*)path range:(NSRange)range block:(RangeBlock)callback;
- (id)init:(MimsyPath*)path line:(NSUInteger)line col:(NSUInteger)col block:(RangeBlock)callback;
- (id)init:(TranscriptController*)controller range:(NSRange)range;

/// If the range has become invalidated (e.g. the associated text was
/// deleted) then the location will be NSNotFound.
@property (readonly) NSRange range;

@property (readonly) MimsyPath* path;

@property (readonly) __weak BaseTextController* controller;

@end
