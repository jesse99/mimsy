#import "TextController.h"

#import "TextDocument.h"

@interface TextController ()

@end

@implementation TextController

- (id)init
{
    self = [super initWithWindowNibName:@"TextDocument"];
    if (self)
	{
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[[self document] controllerDidLoad];
}

- (void) open
{
	// TODO: need to do this stuff
	//Broadcaster.Invoke("opening document window", m_boss);
	
	[self.window makeKeyAndOrderFront:self];
	
	__weak id this = self;
	[[self.view layoutManager] setDelegate:this];
	
	//Broadcaster.Invoke("opened document window", m_boss);
	//synchronizeWindowTitleWithDocumentName();		// bit of a hack, but we need something like this for IDocumentWindowTitle to work
	
	//DoSetTabSettings();
}

@end
