#import "FindInFilesController.h"

#import "Assert.h"
#import "BaseTextController.h"
#import "DirectoryController.h"
#import "Logger.h"
#import "AppSettings.h"

static FindInFilesController* _findFilesController = nil;

@implementation FindInFilesController
{
	NSString* _alwaysExcludeGlobs;
}

- (id)init
{
	self = [super initWithWindowNibName:@"FindInFilesWindow"];
    if (self)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openedDir:) name:@"OpenedDirectory" object:nil];
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
				[self.directoryMenu addItemWithTitle:url.path];
				[self.directoryMenu selectItemWithTitle:url.path];
			}
		}
	}
}

- (IBAction)reset:(id)sender
{
	UNUSED(sender);

	NSString* value = [AppSettings stringValue:@"FindAllIncludes" missing:@""];
	[self.includedGlobsComboBox setStringValue:value];
	
	value = [AppSettings stringValue:@"FindAllExcludes" missing:@""];
	[self.excludedGlobsComboBox setStringValue:value];
	
	value = [AppSettings stringValue:@"FindAllAlwaysExclude" missing:@""];
	self->_alwaysExcludeGlobs = value;

	NSArray* values = [AppSettings stringValues:@"DefaultFindAllDirectory"];
	[self.directoryMenu removeAllItems];
	[self.directoryMenu addItemsWithTitles:values];
	[self _addOpenDirectoriesToMenu];
	
	DirectoryController* controller = [DirectoryController getCurrentController];
	if (controller)
		[self.directoryMenu selectItemWithTitle:controller.path];
}

- (void)openedDir:(NSNotification*)notification
{
	DirectoryController* controller = notification.object;
	[self.directoryMenu addItemWithTitle:controller.path];	
}

- (void)_addOpenDirectoriesToMenu
{
	[DirectoryController enumerate:
		^(DirectoryController *controller)
		{
			[self.directoryMenu addItemWithTitle:controller.path];
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
