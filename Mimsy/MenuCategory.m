#import "MenuCategory.h"

#import "AppDelegate.h"
#import "ProcFiles.h"
#import "ProcFileSystem.h"

@implementation NSMenu (MenuCategory)

- (NSMenuItem *)addSortedItemWithTitle:(NSString *)title action:(SEL)selector keyEquivalent:(NSString *)charCode
{
    for (NSInteger i = 0; i < self.numberOfItems; ++i)
    {
        NSMenuItem* item = [self itemAtIndex:i];
        if ([item.title compare:title] != NSOrderedAscending)
        {
            item = [self insertItemWithTitle:title action:selector keyEquivalent:charCode atIndex:i];
            return item;
        }
    }
    
    return [self addItemWithTitle:title action:selector keyEquivalent:charCode];
}

- (void) insertSortedItem:(NSMenuItem *)newItem atIndex:(NSInteger)index
{
    for (NSInteger i = index; i < self.numberOfItems; ++i)
    {
        NSMenuItem* item = [self itemAtIndex:i];
        if (item.isSeparatorItem || [item.title compare:newItem.title] != NSOrderedAscending)
        {
            [self insertItem:newItem atIndex:i];
            return;
        }
    }
    
    [self insertItem:newItem atIndex:self.numberOfItems];
}


#if OLD_EXTENSIONS
- (void)addExtensionItems:(NSString*)root contents:(NSString*)contents
{
    ProcFileReader* menuSelection = _createReader(@"menu-selection", root, ^NSString *() {
        return contents;
    });
    ProcFileReadWrite* menuContent = _createWriter(@"menu-content", root, ^(NSString *text) {
        NSArray* lines = [text componentsSeparatedByString:@"\n"];
        if (lines.count == 2)
        {
            NSMenuItem* item = [self addSortedItemWithTitle:lines[0] action:@selector(_extensionItemClicked:) keyEquivalent:@""];
            [item setTarget:self];
            
            NSArray* args = @[root, [NSString stringWithFormat:@"%@\n%@", lines[1], contents]];
            [item setRepresentedObject:args];
        }
        else
        {
            LOG("Extensions", "malformed menu-content write: %s", STR(text));
        }
    });
    
    [menuSelection notifyIfChangedBlocking];
    [menuContent close];
    [menuSelection close];
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    ProcFileSystem* fs = app.procFileSystem;
    [fs removeWriter:menuContent];
    [fs removeReader:menuSelection];
}

- (void)_extensionItemClicked:(NSMenuItem*)item
{
    NSArray* args = item.representedObject;
    ProcFileReader* menuAction = _createReader(@"menu-action", args[0], ^NSString *() {
        return args[1];
    });
    [menuAction notifyIfChangedBlocking];    // TODO: bit safer to use notifyIfChangedNonBlocking but we'd need to somehow ensure that we kept only one menuAction alive at any one time
    [menuAction close];
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    ProcFileSystem* fs = app.procFileSystem;
    [fs removeReader:menuAction];
}


static ProcFileReader* _createReader(NSString* name, NSString* root, NSString* (^readBlock)())
{
    ProcFileReader* file = nil;
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    ProcFileSystem* fs = app.procFileSystem;
    if (fs)
    {
        file = [[ProcFileReader alloc]
                initWithDir:^NSString *{return root;}
                fileName:name
                readStr:readBlock];
        [fs addReader:file];
    }
    
    return file;
}

static ProcFileReadWrite* _createWriter(NSString* name, NSString* root, void (^writeBlock)(NSString* text))
{
    ProcFileReadWrite* file = nil;
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    ProcFileSystem* fs = app.procFileSystem;
    if (fs)
    {
        file = [[ProcFileReadWrite alloc]
                initWithDir:^NSString *{return root;}
                fileName:name
                readStr:^NSString*
                {
                    return @"";
                }
                writeStr:writeBlock];
        [fs addWriter:file];
    }
    
    return file;
}
#endif

@end
