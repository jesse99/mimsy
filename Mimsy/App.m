#import "App.h"

#import "AppDelegate.h"

@implementation App

- (void)addWindowsItem:(NSWindow *)window title:(NSString *)title filename:(BOOL)isFilename
{
    [super addWindowsItem:window title:title filename:isFilename];
    
    NSString* key = [NSString stringWithFormat:@"_updateWindowMenu-%@", window.title];
    [AppDelegate execute:key deferBy:0.2 withBlock:^{
        [self _updateWindowMenu:window];
    }];
}

- (void)changeWindowsItem:(NSWindow *)window title:(NSString *)title filename:(BOOL)isFilename
{
    [super changeWindowsItem:window title:title filename:isFilename];

    NSString* key = [NSString stringWithFormat:@"_updateWindowMenu-%@", title];
    [AppDelegate execute:key deferBy:0.2 withBlock:^{
        [self _updateWindowMenu:window];
    }];
}

// Cocoa provides some hooks like the ones above to customize window menu items but there
// doesn't appear to be a good way to customize the appearence other than providing a custom
// view or excluding windows from the menu and managing them yourself. So we let Cocoa do its
// thing, wait a bit, and then set attributes ourself.
- (void)_updateWindowMenu:(NSWindow*)window
{
    // Make directory windows bold.
    NSObject* controller = window.windowController;
    if ([controller.className isEqualToString:@"DirectoryController"])
    {
        NSMenuItem* item = [self _getWindowMenuItem:window];
        if (item)
        {
            
            NSDictionary* attrs = @{NSFontAttributeName: [NSFont menuBarFontOfSize:0.0]};
            NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:item.title attributes:attrs];
            [str applyFontTraits:NSBoldFontMask range:NSMakeRange(0, str.length)];
            [item setAttributedTitle:str];
        }
    }
    
    // Make non-text documents italic (e.g. the transcript and find in files result windows).
    else if (![controller.className isEqualToString:@"TextController"])
    {
        NSMenuItem* item = [self _getWindowMenuItem:window];
        if (item)
        {
            NSDictionary* attrs = @{
                NSFontAttributeName: [NSFont menuBarFontOfSize:0.0],
                NSObliquenessAttributeName: @(0.15)};
            NSAttributedString* str = [[NSAttributedString alloc] initWithString:item.title attributes:attrs];
            [item setAttributedTitle:str];
        }
    }
}

- (NSMenuItem*)_getWindowMenuItem:(NSWindow*)window
{
    NSMenuItem* item = nil;
    
    NSInteger index = [self.windowsMenu indexOfItemWithTarget:window andAction:@selector(makeKeyAndOrderFront:)];
    if (index >= 0)
        item = [self.windowsMenu itemAtIndex:index];
    
    return item;
}

@end
