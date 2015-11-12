#import <Foundation/Foundation.h>

typedef void (^MessageHandler)(NSDictionary* message);

@interface ExtensionConnection : NSObject

- (id)init:(CFSocketNativeHandle)socketH;

- (void)open;
- (void)close;

- (void)sendNotification:(NSString*)method;

@property (readonly) NSString* name;
@property (readonly) NSString* version;
@property (readonly) NSString* url;

@end
