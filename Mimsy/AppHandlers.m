#import "AppHandlers.h"

#import "ExtensionConnection.h"
#import "Logger.h"

void registerAppHandlers(void)
{
    [ExtensionConnection registerHandler:@"log" handler:^(NSDictionary *message) {
        NSString* topic = message[@"Topic"];
        NSString* text = message[@"Text"];
        LOG(STR(topic), "%s", STR(text));
    }];
}
