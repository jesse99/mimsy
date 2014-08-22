#import "SelectStyleController.h"

#import "ConfigParser.h"
#import "Glob.h"
#import "Logger.h"
#import "Paths.h"
#import "TextController.h"
#import "TranscriptController.h"
#import "Utils.h"

static SelectStyleController* _controller;

@interface StyleRowObject : NSObject
@property NSString* name;
@property NSString* path;
@property NSString* rating;
@property NSString* comment;
@end

@implementation StyleRowObject
@end

@implementation SelectStyleController
{
	NSMutableArray* _rows;
	NSString* _default;
	NSTimer* _writeTimer;
	bool emittedError;
}

- (id)init
{
	self = [super initWithWindowNibName:@"SelectStyleWindow"];
	
	_rows = [NSMutableArray new];
	
	// We use this to schedule a write to the settings file after edits. By default it
	// fires every year (it needs to repeat so that we can adjust the fire time after
	// edits).
	_writeTimer = [NSTimer scheduledTimerWithTimeInterval:32000.0 target:self selector:@selector(_saveSettings) userInfo:nil repeats:YES];
	
 	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stylesChanged:) name:@"StylesChanged" object:nil];
 	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stylesChanged:) name:@"SettingsChanged" object:nil];
   
    return self;
}

+ (SelectStyleController*)open
{
	if (!_controller)
		_controller = [SelectStyleController new];
	if (_controller.isWindowLoaded)
		[_controller _selectDefault];
	
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
		[temp setDoubleAction:@selector(onDoubleClick:)];
		
		[self _reloadStyles];
	}
}

- (void)stylesChanged:(NSNotification*)notification
{
	(void) notification;
	
	[self _reloadStyles];
}

- (NSArray*)getHelpContext
{
	return @[@"select style"];
}

- (IBAction)setDefault:(id)sender
{
	(void) sender;
	
	NSTableView* temp = _table;
	if (temp)
	{
		StyleRowObject* object = _rows[(NSUInteger)temp.selectedRow];
		_default = object.name;
		[TextController enumerate:
			^(TextController* controller)
			{
				if (controller && controller.language)
				{
					[controller changeStyle:object.path];
				}
			}
		];

		[temp reloadData];
		[_writeTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	}
}

- (void)onDoubleClick:(NSTableView*)sender
{
	StyleRowObject* object = _rows[(NSUInteger)sender.clickedRow];

	NSURL* url = [[NSURL alloc] initFileURLWithPath:object.path];
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES completionHandler:
		^(NSDocument* document, BOOL documentWasAlreadyOpen, NSError* error)
		{
			(void) document;
			(void) documentWasAlreadyOpen;
			
			if (error)
			{
				NSString* reason = [error localizedFailureReason];
				NSString* mesg = [NSString stringWithFormat:@"Couldn't open %@: %@", object.path, reason];
				[TranscriptController writeError:mesg];
			}
		}];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView* )view
{
	(void) view;
	
	return (NSInteger) _rows.count;
}

- (id)tableView:(NSTableView* )view objectValueForTableColumn:(NSTableColumn*)column row:(NSInteger)row
{
	(void) view;
	
	id value = nil;

	StyleRowObject* object = _rows[(NSUInteger)row];
	if ([column.identifier isEqualToString:@"0"])
	{
		value = object.name;
	}
	else if ([column.identifier isEqualToString:@"1"])
	{
		value = object.rating;
	}
	else if ([column.identifier isEqualToString:@"2"])
	{
		value = object.comment;
	}
	else
	{
		assert(false);
	}
	
	// Render text on the default row with bold.
	if (value && [object.name isEqualToString:_default])
	{
		NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:value];
		[str setAttributes:@{NSStrokeWidthAttributeName:@-3.0} range:NSMakeRange(0, [value length])];
		value = str;
	}
	
	return value;
}

- (void)tableView:(NSTableView*)view setObjectValue:(id)newValue forTableColumn:(NSTableColumn*)column row:(NSInteger)row
{
	(void) view;
	
	StyleRowObject* object = _rows[(NSUInteger)row];	
	if ([column.identifier isEqualToString:@"1"])
	{
		// For ease of sorting we only allow asterisks in the rating column.
		// To avoid confusion about what the user can type we'll simply map
		// anything they type to asterisks.
		object.rating = [[newValue description] map:
			^unichar(unichar ch)
			{
				(void) ch;
				return '*';
			}
		];
		[_writeTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
	}
	else if ([column.identifier isEqualToString:@"2"])
	{
		object.comment = newValue;
		[_writeTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
	}
	else
	{
		assert(false);
	}
}

- (void)tableViewSelectionDidChange:(NSNotification*)notification
{
	(void) notification;
	
	NSTableView* temp = _table;
	if (temp)
	{
		if (temp.window.isVisible)
		{
			NSUInteger row = (NSUInteger) temp.selectedRow;
			StyleRowObject* object = _rows[(NSUInteger)row];
			if (row < _rows.count)
			{
				TextController* controller = [TextController frontmost];
				if (controller && controller.language)
				{
					[controller changeStyle:object.path];
				}
				else if (!emittedError)
				{
					NSString* mesg = @"To see what the style looks like open a document with syntax highlighting enabled.";
					[TranscriptController writeError:mesg];
					emittedError = true;
				}
			}
			
			NSButton* button = _makeDefaultButton;
			if (button)
				[button setEnabled:![object.name isEqualToString:_default]];
		}
	}
}

- (void)tableView:(NSTableView*)view sortDescriptorsDidChange:(NSArray*)oldDescriptors
{
	(void) oldDescriptors;
	
	// sortUsingDescriptors is a stable sort so sorting first by name is helpful.
	[_rows sortUsingComparator:
		^NSComparisonResult(StyleRowObject* lhs, StyleRowObject* rhs)
		{
			return [lhs.name compare:rhs.name options:NSCaseInsensitiveSearch];
		}
	];
	[_rows sortUsingDescriptors:[view sortDescriptors]];
	[view reloadData];
}

- (void)_reloadStyles
{
	NSTableView* temp = self.table;
	if (temp)
	{
		[self _loadStyleNames];
		[self _loadSettings];
		[temp reloadData];
		[self _selectDefault];
	}
}

- (void)_selectDefault
{
	NSUInteger i = [_rows indexOfObjectPassingTest:
		^BOOL(StyleRowObject* obj, NSUInteger index, BOOL* stop)
		{
			(void) stop;
			(void) index;
			return [obj.name isEqualToString:_default];
		}];

	NSTableView* temp = _table;
	if (i != NSNotFound && temp)
	{
		NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:i];
		[temp selectRowIndexes:indexes byExtendingSelection:NO];
		[temp scrollRowToVisible:(NSInteger)i];
	}

	NSButton* button = _makeDefaultButton;
	if (button)
		[button setEnabled:i == NSNotFound || !temp];
}

- (void)_loadStyleNames
{
	NSMutableArray* rows = [NSMutableArray new];
	
	NSString* dir = [Paths installedDir:@"styles"];
	Glob* glob = [[Glob alloc] initWithGlob:@"*.rtf"];
	
	NSError* error = nil;
	[Utils enumerateDeepDir:dir glob:glob error:&error block:
	 ^(NSString* path)
	 {
		 if (![path hasSuffix:@"README.rtf"])
		 {
			 StyleRowObject* object = [StyleRowObject new];
			 object.name = [path substringFromIndex:dir.length+1];
			 object.path = path;
			 [rows addObject:object];
		 }
	 }
	 ];
	if (error)
		[TranscriptController writeError:[error localizedFailureReason]];

	_rows = rows;
}

- (void)_loadSettings
{
	NSString* dir = [Paths installedDir:@"settings"];
	NSString* path = [dir stringByAppendingPathComponent:@"styles.mimsy"];

	NSError* error = nil;
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (parser)
	{
		[parser enumerate:
			^(ConfigParserEntry* entry)
			{
				if ([entry.key isEqualToString:@"Default"])
				{
					_default = entry.value;
				}
				else
				{
					NSArray* parts = [entry.value componentsSeparatedByString:@"|"];
					if (parts.count == 2)
					{
						NSUInteger i = [_rows indexOfObjectPassingTest:
							^BOOL(StyleRowObject* obj, NSUInteger index, BOOL* stop)
							{
								(void) stop;
								(void) index;
								return [obj.name isEqualToString:entry.key];
							}];
						
						if (i != NSNotFound)
						{
							if ([parts[0] length])
								[_rows[i] setRating:parts[0]];
							
							if ([parts[1] length])
								[_rows[i] setComment:parts[1]];
						}
					}
					else
					{
						NSString* mesg = [[NSString alloc] initWithFormat:@"Expected a value formatted as rating|comment in %@ on line %lu", path, entry.line];
						[TranscriptController writeError:mesg];
					}
				}
			}
		 ];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load %@:\n%@", path, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
	}
}

- (void)_saveSettings
{
	NSMutableString* str = [NSMutableString stringWithCapacity:1024];
	
	[str appendString:@"# This is used to control which style file is the default and to contain the ratings and\n"];
	[str appendString:@"# comments for style files. You can edit it manually, but more commonly it is edited via\n"];
	[str appendString:@"# the Select Style menu option in the Mimsy menu.\n"];
	
	[str appendFormat:@"Default: %@\n", _default];
	[str appendString:@"\n"];
	
	for (StyleRowObject* object in _rows)
	{
		if (object.rating || object.comment)
		{
			[str appendFormat:@"%@: %@|%@\n", object.name,
				object.rating ? object.rating : @"",
				object.comment ? object.comment : @""];
		}
	}
	
	[self _writeSettings:str];
}

- (void)_writeSettings:(NSString*)content
{
	NSString* dir = [Paths installedDir:@"settings"];
	NSString* path = [dir stringByAppendingPathComponent:@"styles.mimsy"];
	
	NSError* error = nil;
	BOOL written = [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
	if (!written)
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to write %@: %@", path, reason];
		[TranscriptController writeError:mesg];
	}
}

@end
