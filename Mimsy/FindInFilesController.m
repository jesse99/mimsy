#import "FindInFilesController.h"

#import "Assert.h"
#import "BaseTextController.h"
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
        // Initialization code here.
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
	LOG_INFO("Mimsy", "find all");
}

- (IBAction)replaceAll:(id)sender
{
	UNUSED(sender);
	LOG_INFO("Mimsy", "replace all");
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
}

- (IBAction)addDirectory:(id)sender
{
	UNUSED(sender);
	LOG_INFO("Mimsy", "add directory");
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
