#import "SetStyleController.h"

#import "Glob.h"
#import "Logger.h"
#import "Paths.h"
#import "TranscriptController.h"
#import "Utils.h"

static SetStyleController* _window;

@implementation SetStyleController
{
	NSArray* _styleNames;
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
	if (!_window)
		_window = [SetStyleController new];
	[_window showWindow:NSApp];
	return _window;
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

- (void)_loadStyleNames
{
	NSMutableArray* names = [NSMutableArray new];
	
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
		 }
	 }
	 ];
	LOG_INFO("Mimsy", "loaded %lu styles", names.count);
	if (error)
		[TranscriptController writeError:[error localizedFailureReason]];

	_styleNames = names;
}

@end
