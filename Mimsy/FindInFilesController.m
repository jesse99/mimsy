#import "FindInFilesController.h"

#import "AppDelegate.h"
#import "BaseTextController.h"
#import "DirectoryController.h"
#import "FindInFiles.h"
#import "ReplaceInFiles.h"

static FindInFilesController* _findFilesController = nil;

@implementation FindInFilesController
{
	NSString* _alwaysExcludeGlobs;
	bool _reversedPaths;
	NSMutableDictionary* _normalPaths;
}

- (id)init
{
	self = [super initWithWindowNibName:@"FindInFilesWindow"];
    if (self)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openedDir:) name:@"OpenedDirectory" object:nil];
        AppDelegate* app = [NSApp delegate];
		_reversedPaths = [app.layeredSettings boolValue:@"ReversePaths" missing:true];
		_normalPaths = [NSMutableDictionary new];
    }
    
    return self;
}

+ (void)show
{
	FindInFilesController* controller = [FindInFilesController getController];
	
	[controller showWindow:controller.window];
	[controller.window makeKeyAndOrderFront:self];
	[controller.window makeFirstResponder:controller.findComboBox];
	
	[controller _enableButtons];
}

+ (FindInFilesController*)getController
{
	if (!_findFilesController)
	{
		_findFilesController = [FindInFilesController new];
		(void) _findFilesController.window;				// this forces the controls to be initialized (so we can set the text within the find combo box before the window is ever displayed)
			
		[_findFilesController reset:self];
	}
	return _findFilesController;	
}

- (bool)singleFile
{
	return false;
}

- (NSArray*)getHelpContext
{
	return @[@"find all", @"find"];
}

- (void)_updateControlsForReplace:(bool)replacing
{
	[self _updateComboBox:self.findComboBox with:self.findText];
	[self _updateComboBox:self.includedGlobsComboBox with:self.includedGlobsComboBox.stringValue];
	[self _updateComboBox:self.excludedGlobsComboBox with:self.excludedGlobsComboBox.stringValue];
	if (replacing)
		[self _updateComboBox:self.replaceWithComboBox with:self.replaceText];
}

- (IBAction)findAll:(id)sender
{
	UNUSED(sender);
	
	MimsyPath* directory = [self _getSelectedDirectory];
	if (directory)
	{
		[self _updateControlsForReplace:false];
		
		FindInFiles* finder = [[FindInFiles alloc] init:self path:[self _getSelectedDirectory]];
		[finder findAll];
	}
}

- (IBAction)replaceAll:(id)sender
{
	UNUSED(sender);

	MimsyPath* directory = [self _getSelectedDirectory];
	if (directory)
	{
		[self _updateControlsForReplace:true];
		NSString* template = [self _getReplaceTemplate];
		
		ReplaceInFiles* finder = [[ReplaceInFiles alloc] init:self path:[self _getSelectedDirectory] template:template];
		[finder replaceAll];
	}
}

- (IBAction)addDirectory:(id)sender
{
	UNUSED(sender);

	NSOpenPanel* panel = [NSOpenPanel new];
	[panel setTitle:@"Open Directory"];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	[panel setCanCreateDirectories:YES];
	[panel setAllowsMultipleSelection:YES];
	
	NSInteger button = [panel runModal];
	if (button == NSModalResponseOK)
	{
		for (NSURL* url in panel.URLs)
		{
			if (url.isFileURL)
			{
				[self _addPathToDirectoryMenu:url.path];
				[self _selectPathInDirectoryMenu:url.path];
			}
		}
	}
}

- (MimsyPath*)_getSelectedDirectory
{
	NSString* selected = [self.directoryMenu titleOfSelectedItem];
	
	if (_reversedPaths)
	{
		selected = [_normalPaths valueForKey:selected];
	}
	
	return [[MimsyPath alloc] initWithString:selected];
}

- (void)_addPathToDirectoryMenu:(NSString*)path
{
	if (_reversedPaths)
	{
		NSString* reversed = [path reversePath];
		_normalPaths[reversed] = path;
		[self.directoryMenu addItemWithTitle:reversed];
	}
	else
	{
		[self.directoryMenu addItemWithTitle:path];
	}
}

- (void)_selectPathInDirectoryMenu:(NSString*)path
{
	if (_reversedPaths)
		[self.directoryMenu selectItemWithTitle:[path reversePath]];
	else
		[self.directoryMenu selectItemWithTitle:path];
}

- (IBAction)reset:(id)sender
{
	UNUSED(sender);

    AppDelegate* app = [NSApp delegate];
	_reversedPaths = [app.layeredSettings boolValue:@"ReversePaths" missing:true];
	_normalPaths = [NSMutableDictionary new];

	NSString* value = [app.layeredSettings stringValue:@"FindAllIncludes" missing:@""];
	[self.includedGlobsComboBox setStringValue:value];
	
	value = [app.layeredSettings stringValue:@"FindAllExcludes" missing:@""];
	[self.excludedGlobsComboBox setStringValue:value];
	
	value = [app.layeredSettings stringValue:@"FindAllAlwaysExclude" missing:@""];
	self->_alwaysExcludeGlobs = value;

	NSArray* values = [app.layeredSettings stringValues:@"DefaultFindAllDirectory"];
	[self.directoryMenu removeAllItems];
	for (NSString* title in values)
	{
		[self _addPathToDirectoryMenu:title];
	}
	[self _addOpenDirectoriesToMenu];
	
	DirectoryController* controller = [DirectoryController getCurrentController];
	if (controller)
		[self _selectPathInDirectoryMenu:controller.path.asString];
}

- (void)openedDir:(NSNotification*)notification
{
	DirectoryController* controller = notification.object;
	[self _addPathToDirectoryMenu:controller.path.asString];
}

- (void)_addOpenDirectoriesToMenu
{
	[DirectoryController enumerate:
		^(DirectoryController *controller)
		{
			[self _addPathToDirectoryMenu:controller.path.asString];
		}];
}

- (void)_enableButtons
{
	bool findable = self.findText.length > 0 && self.directoryMenu.numberOfItems > 0;
	
	[self.findAllButton setEnabled:findable];
	[self.replaceAllButton setEnabled:findable];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
	UNUSED(obj);
	[_findFilesController _enableButtons];
}

@end
