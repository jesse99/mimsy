#import <Foundation/Foundation.h>

// Used to add search on various web sites to both the main menu and context menus.
@interface SearchSite : NSObject

+(void)updateMainMenu:(NSMenu*)searchMenu;

+(void)appendContextMenu:(NSMenu*)menu;

@end
