#import "MimsyHandlers.h"

#import "ExtensionConnection.h"
#import "Logger.h"

void registerMimsyHandlers(void)
{
    [ExtensionConnection registerHandler:@"log" handler:^(NSDictionary *message) {
        NSString* topic = message[@"topic"];
        NSString* text = message[@"text"];
        LOG(STR(topic), "%s", STR(text));
    }];
}
