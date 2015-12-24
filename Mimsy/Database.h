#import <Foundation/Foundation.h>

/// Simple wrapper around sqlite. Note that the underlying sqlite database
/// is thread safe but instances of this class should not be shared across
/// threads.
@interface Database : NSObject

- (void)dealloc;

/// Opens a connection to a new or existing database at path.
- (id)initWithPath:(NSString*)path error:(NSError**)error;

/// Used for SQL commands that do not return a result.
- (bool)update:(NSString*)command error:(NSError**)error;

/// Returns an array of rows where each row is an array of strings.
/// Note that this should not be used from the main thread if there
/// is a chance that lots of rows can be returned.
- (NSArray*)queryRows:(NSString*)command error:(NSError**)error;

/// TODO: Continuum's Database class had some features that we may
/// want to add:
/// 1) Transactions (the Update method that took a callback).
/// 2) A Query method that took a callback (more efficient than
/// collecting all the results and also allows early exits).
/// 3) A QueryNamedRows method that allowed query results to be
/// looked up by name instead of index.

@end
