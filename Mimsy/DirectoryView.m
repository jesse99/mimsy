#import "DirectoryView.h"

#import "AppDelegate.h"
#import "DirectoryController.h"
#import "FolderItem.h"
#import "Logger.h"
#import "ProcFiles.h"
#import "ProcFileSystem.h"
#import "TranscriptController.h"

@implementation DirectoryView
{
    NSMutableArray* _files;
    NSMutableArray* _dirs;
    NSMenu* _contextMenu;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    
    if (self)
    {
        _files = [NSMutableArray new];
        _dirs = [NSMutableArray new];
    }
    
    return self;
}

// As of 10.5 the preferred way to do this is to setup a menu in the xib, bind it to
// the window controller, and define a menuNeedsUpdate method. However that doesn't
// seem to work so well with table views because we want to adjust the selection as
// well.
- (NSMenu*)menuForEvent:(NSEvent*)event
{
    // If we're going to do directory window stuff it's probably a good idea to bring
    // the directory window to the front.
    //[self.window makeKeyAndOrderFront:self];
    
    // If the item the user clicked on is not selected then select it.
    NSPoint baseLoc = event.locationInWindow;
    NSPoint viewLoc = [self convertPoint:baseLoc fromView:nil];
    NSInteger row = [self rowAtPoint:viewLoc];
    if (row >= 0)
    {
        if (![self isRowSelected:row])
        {
            NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:(NSUInteger)row];
            [self selectRowIndexes:indexes byExtendingSelection:false];
        }
    }
    
    // Find all the items that are selected.
    _files = [NSMutableArray new];
    _dirs = [NSMutableArray new];

    NSWorkspace* ws = [NSWorkspace sharedWorkspace];
    [self.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        UNUSED(stop);
        
        FileSystemItem* item = [self itemAtRow:(NSInteger)index];
        if ([item isMemberOfClass:[FolderItem class]] || [ws isFilePackageAtPath:item.path])
            [_dirs addObject:item.path];
        else
            [_files addObject:item.path];
    }];
    
    // Populate the menu.
    _contextMenu = [[NSMenu alloc] initWithTitle:@""];
    
    ProcFileReader* menuSelection = [self _createReader:@"menu-selection" readBlock:^NSString *() {
        NSString* result = [NSString stringWithFormat:@"%@\n%@",
                            [_files componentsJoinedByString:@"\f"],
                            [_dirs componentsJoinedByString:@"\f"]];
        return result;
    }];
    ProcFileReadWrite* menuContent = [self _createWriter:@"menu-content" readBlock:^(NSString *text) {
        NSArray* lines = [text componentsSeparatedByString:@"\n"];
        if (lines.count == 2)
        {
            NSMenuItem* item = [_contextMenu addItemWithTitle:lines[0] action:@selector(contextMenuClicked:) keyEquivalent:@""];
            [item setTarget:self];
            [item setRepresentedObject:lines[1]];
        }
        else
        {
            LOG("Extensions", "malformed menu-content write: %s", STR(text));
        }
    }];
    
    [menuSelection notifyIfChangedBlocking];
    [menuContent close];
    [menuSelection close];
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    ProcFileSystem* fs = app.procFileSystem;
    [fs removeWriter:menuContent];
    [fs removeReader:menuSelection];
    
    return _contextMenu;
}

- (void)contextMenuClicked:(NSMenuItem*)item
{
    ProcFileReader* menuAction = [self _createReader:@"menu-action" readBlock:^NSString *() {
        NSString* result = [NSString stringWithFormat:@"%@\n%@\n%@",
                            [item.representedObject description],
                            [_files componentsJoinedByString:@"\f"],
                            [_dirs componentsJoinedByString:@"\f"]];
        return result;
    }];
    [menuAction notifyIfChangedBlocking];    // TODO: bit safer to use notifyIfChangedNonBlocking but we'd need to somehow ensure that we kept only one menuAction alive at any one time
    [menuAction close];
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    ProcFileSystem* fs = app.procFileSystem;
    [fs removeReader:menuAction];
}

- (void)keyDown:(NSEvent*)event
{
	const int ReturnKey = 36;
	const int DeleteKey = 51;
	
	if (event.keyCode == DeleteKey && (event.modifierFlags & NSCommandKeyMask))
	{
		DirectoryController* controller = (DirectoryController*) self.window.windowController;
		[controller deleted:self];
	}
	else if (event.keyCode == ReturnKey)
	{
		DirectoryController* controller = (DirectoryController*) self.window.windowController;
		[controller doubleClicked:self];
	}
	else
	{
		LOG("Mimsy:Verbose", "keyCode = %u, flags = %lX", event.keyCode, event.modifierFlags);
		[super keyDown:event];
	}
}

- (ProcFileReader*)_createReader:(NSString*)name readBlock:(NSString* (^)())readBlock
{
    ProcFileReader* file = nil;
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    ProcFileSystem* fs = app.procFileSystem;
    if (fs)
    {
        file = [[ProcFileReader alloc]
                initWithDir:^NSString *{return @"/directory";}
                fileName:name
                readStr:readBlock];
        [fs addReader:file];
    }
    
    return file;
}

- (ProcFileReadWrite*)_createWriter:(NSString*)name readBlock:(void (^)(NSString* text))writeBlock
{
    ProcFileReadWrite* file = nil;
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    ProcFileSystem* fs = app.procFileSystem;
    if (fs)
    {
        file = [[ProcFileReadWrite alloc]
                initWithDir:^NSString *{return @"/directory";}
                fileName:name
                readStr:^NSString*
                {
                    return @"";
                }
                writeStr:writeBlock];
        //[fs addReader:file];
        [fs addWriter:file];
    }
    
    return file;
}

@end

