#import "FindInFilesController.h"

#import "AppSettings.h"
#import "Assert.h"
#import "BaseTextController.h"
#import "DirectoryController.h"
#import "Logger.h"
#import "StringCategory.h"

static FindInFilesController* _findFilesController = nil;

@implementation FindInFilesController
{
	NSString* _alwaysExcludeGlobs;
	bool _reversedPaths;
}

- (id)init
{
	self = [super initWithWindowNibName:@"FindInFilesWindow"];
    if (self)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openedDir:) name:@"OpenedDirectory" object:nil];
		_reversedPaths = [AppSettings boolValue:@"ReversePaths" missing:true];
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

- (NSArray*)getHelpContext
{
	return @[@"find"];
}

- (IBAction)findAll:(id)sender
{
	UNUSED(sender);

	NSString* findText = self.findText;
	[self _updateComboBox:self.findComboBox with:findText];
	[self _updateComboBox:self.includedGlobsComboBox with:self.includedGlobsComboBox.stringValue];
	[self _updateComboBox:self.excludedGlobsComboBox with:self.excludedGlobsComboBox.stringValue];
}

- (IBAction)replaceAll:(id)sender
{
	UNUSED(sender);

	NSString* findText = self.findText;
	[self _updateComboBox:self.findComboBox with:findText];
	[self _updateComboBox:self.includedGlobsComboBox with:self.includedGlobsComboBox.stringValue];
	[self _updateComboBox:self.excludedGlobsComboBox with:self.excludedGlobsComboBox.stringValue];
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
	if (button == NSOKButton)
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

- (void)_addPathToDirectoryMenu:(NSString*)path
{
	if (_reversedPaths)
		[self.directoryMenu addItemWithTitle:[path reversePath]];
	else
		[self.directoryMenu addItemWithTitle:path];
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

	_reversedPaths = [AppSettings boolValue:@"ReversePaths" missing:true];

	NSString* value = [AppSettings stringValue:@"FindAllIncludes" missing:@""];
	[self.includedGlobsComboBox setStringValue:value];
	
	value = [AppSettings stringValue:@"FindAllExcludes" missing:@""];
	[self.excludedGlobsComboBox setStringValue:value];
	
	value = [AppSettings stringValue:@"FindAllAlwaysExclude" missing:@""];
	self->_alwaysExcludeGlobs = value;

	NSArray* values = [AppSettings stringValues:@"DefaultFindAllDirectory"];
	[self.directoryMenu removeAllItems];
	for (NSString* title in values)
	{
		[self _addPathToDirectoryMenu:title];
	}
	[self _addOpenDirectoriesToMenu];
	
	DirectoryController* controller = [DirectoryController getCurrentController];
	if (controller)
		[self _selectPathInDirectoryMenu:controller.path];
}

- (void)openedDir:(NSNotification*)notification
{
	DirectoryController* controller = notification.object;
	[self _addPathToDirectoryMenu:controller.path];
}

- (void)_addOpenDirectoriesToMenu
{
	[DirectoryController enumerate:
		^(DirectoryController *controller)
		{
			[self _addPathToDirectoryMenu:controller.path];
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
