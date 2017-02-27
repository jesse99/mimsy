#import "DirectoryView.h"

#import "AppDelegate.h"
#import "DirectoryController.h"
#import "FolderItem.h"
#import "Logger.h"
#import "MenuCategory.h"
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
        if ([item isMemberOfClass:[FolderItem class]] || [ws isFilePackageAtPath:item.path.asString])
            [_dirs addObject:item.path];
        else
            [_files addObject:item.path];
    }];
    
    // Populate the menu.
    _contextMenu = [[NSMenu alloc] initWithTitle:@""];
    
    [self _addPluginItems];
    
    return _contextMenu;
}

- (void)_addPluginItems
{
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    for (ProjectContextItem* citem in app.projectItems)
    {
        NSString* title = (citem.title)(_files, _dirs);
        if (title)
        {
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(_processContextItem:) keyEquivalent:@""];
            [item setRepresentedObject:citem.invoke];
            [_contextMenu appendSortedItem:item];
        }
    }
}

- (void)_processContextItem:(NSMenuItem*)sender
{
    InvokeProjectCommandBlock invoke = sender.representedObject;
    invoke(_files, _dirs);
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

@end

