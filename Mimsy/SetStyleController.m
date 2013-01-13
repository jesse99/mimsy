#import "SetStyleController.h"

#import "Glob.h"
#import "Logger.h"
#import "Paths.h"
#import "TextController.h"
#import "TranscriptController.h"
#import "Utils.h"

static SetStyleController* _controller;

@implementation SetStyleController
{
	NSArray* _styleNames;
	NSArray* _stylePaths;
	bool emittedError;
}

- (id)init
{
	self = [super initWithWindowNibName:@"SetStyle"];
    
    return self;
}

- (IBAction)setDefault:(id)sender
{
	(void) sender;
}

+ (SetStyleController*)open
{
	if (!_controller)
		_controller = [SetStyleController new];
	[_controller showWindow:NSApp];
	_controller->emittedError = false;
	return _controller;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	NSTableView* temp = self.table;
	if (temp)
	{
		__weak id this = self;
		[temp setDelegate:this];
		[temp setDataSource:this];
		
		[self _loadStyleNames];
		[temp reloadData];
	}
}

- (NSInteger)numberOfRowsInTableView:(NSTableView* )view
{
	(void) view;
	
	return (NSInteger) _styleNames.count;
}

- (id)tableView:(NSTableView* )view objectValueForTableColumn:(NSTableColumn*)column row:(NSInteger)row
{
	(void) view;

	if ([column.identifier isEqualToString:@"0"])
	{
		return _styleNames[(NSUInteger)row];
	}
	else if ([column.identifier isEqualToString:@"1"])
	{
		return @"";
	}
	else
	{
		return @"";
	}
}

- (void)tableViewSelectionDidChange:(NSNotification*)notification
{
	(void) notification;
	
	if (_table.window.isVisible)
	{
		NSUInteger row = (NSUInteger) _table.selectedRow;
		if (row < _stylePaths.count)
		{
			TextController* controller = [TextController frontmost];
			if (controller)
			{
				[controller changeStyle:_stylePaths[row]];
			}
			else if (!emittedError)
			{
				NSString* mesg = @"To see what the style looks like open a document with syntax highlighting enabled.";
				[TranscriptController writeError:mesg];
				emittedError = true;
			}
		}
	}
}

- (void)_loadStyleNames
{
	NSMutableArray* names = [NSMutableArray new];
	NSMutableArray* paths = [NSMutableArray new];
	
	NSString* dir = [Paths installedDir:@"styles"];
	Glob* glob = [[Glob alloc] initWithGlob:@"*.rtf"];
	
	NSError* error = nil;
	[Utils enumerateDeepDir:dir glob:glob error:&error block:
	 ^(NSString* path)
	 {
		 if (![path hasSuffix:@"README.rtf"])
		 {
			 NSString* suffix = [path substringFromIndex:dir.length+1];
			 [names addObject:suffix];
			 [paths addObject:path];
		 }
	 }
	 ];
	LOG_INFO("Mimsy", "loaded %lu styles", names.count);
	if (error)
		[TranscriptController writeError:[error localizedFailureReason]];

	_styleNames = names;
	_stylePaths = paths;
}

@end
