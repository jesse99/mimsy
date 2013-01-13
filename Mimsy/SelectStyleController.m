#import "SelectStyleController.h"

#import "ConfigParser.h"
#import "Glob.h"
#import "Logger.h"
#import "Paths.h"
#import "StringCategory.h"
#import "TextController.h"
#import "TranscriptController.h"
#import "Utils.h"

static SelectStyleController* _controller;

@implementation SelectStyleController
{
	NSArray* _styleNames;
	NSArray* _stylePaths;
	NSMutableDictionary* _ratings;
	NSMutableDictionary* _comments;
	NSString* _default;
	bool emittedError;
	NSTimer* _writeTimer;
}

- (id)init
{
	self = [super initWithWindowNibName:@"SelectStyleWindow"];
	
	_ratings = [NSMutableDictionary new];
	_comments = [NSMutableDictionary new];
	
	// We use this to schedule a write to the settings file after edits. By default it
	// fires every year (it needs to repeat so that we can adjust the fire time after
	// edits).
	_writeTimer = [NSTimer scheduledTimerWithTimeInterval:32000.0 target:self selector:@selector(_saveSettings) userInfo:nil repeats:YES];
    
    return self;
}

+ (SelectStyleController*)open
{
	if (!_controller)
		_controller = [SelectStyleController new];
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
		[self _loadSettings];
		[temp reloadData];
	}
}

- (IBAction)setDefault:(id)sender
{
	(void) sender;
	
	_default = _styleNames[(NSUInteger)_table.selectedRow];
	NSString* path = _stylePaths[(NSUInteger)_table.selectedRow];
	[TextController enumerate:
		^(TextController* controller)
		{
			if (controller && controller.language)
			{
				[controller changeStyle:path];
			}
		}
	];

	NSTableView* temp = self.table;
	if (temp)
		[temp reloadData];
	[_writeTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView* )view
{
	(void) view;
	
	return (NSInteger) _styleNames.count;
}

- (id)tableView:(NSTableView* )view objectValueForTableColumn:(NSTableColumn*)column row:(NSInteger)row
{
	(void) view;
	
	id value = nil;

	if ([column.identifier isEqualToString:@"0"])
	{
		value = _styleNames[(NSUInteger)row];
	}
	else if ([column.identifier isEqualToString:@"1"])
	{
		NSString* name = _styleNames[(NSUInteger)row];
		value = _ratings[name];
	}
	else if ([column.identifier isEqualToString:@"2"])
	{
		NSString* name = _styleNames[(NSUInteger)row];
		value = _comments[name];
	}
	else
	{
		assert(false);
	}
	
	// Render text on the default row with bold.
	if (value && [_styleNames[(NSUInteger)row] isEqualToString:_default])
	{
		NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:value];
		[str setAttributes:@{NSStrokeWidthAttributeName:@-3.0} range:NSMakeRange(0, [value length])];
		value = str;
	}
	
	return value;
}

- (void)tableView:(NSTableView*)view setObjectValue:(id)object forTableColumn:(NSTableColumn*)column row:(NSInteger)row
{
	(void) view;
	
	NSString* name = _styleNames[(NSUInteger)row];
	
	if ([column.identifier isEqualToString:@"1"])
	{
		// For ease of sorting we only allow asterisks in the rating column.
		// To avoid confusion about what the user can type we'll simply map
		// anything they type to asterisks.
		_ratings[name] = [[object description] map:
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
		_comments[name] = object;
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
	
	if (_table.window.isVisible)
	{
		NSUInteger row = (NSUInteger) _table.selectedRow;
		if (row < _stylePaths.count)
		{
			TextController* controller = [TextController frontmost];
			if (controller && controller.language)
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
		
		NSButton* button = _makeDefaultButton;
		if (button)
			[button setEnabled:![_styleNames[row] isEqualToString:_default]];
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

- (void)_loadSettings
{
	[_ratings removeAllObjects];
	[_comments removeAllObjects];

	NSString* dir = [Paths installedDir:@"settings"];
	NSString* path = [dir stringByAppendingPathComponent:@"styles.mimsy"];

	NSError* error = nil;
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (!error)
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
						if ([parts[0] length])
							_ratings[entry.key] = parts[0];
						
						if ([parts[1] length])
							_comments[entry.key] = parts[1];
					}
					else
					{
						NSString* mesg = [[NSString alloc] initWithFormat:@"Expected a value formatted as rating|comment in %@ on line %lu\n", path, entry.line];
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
	
	for (NSString* name in _styleNames)
	{
		NSString* rating = _ratings[name];
		NSString* comment = _comments[name];
		if (rating || comment)
		{
			[str appendFormat:@"%@: %@|%@\n", name, rating ? rating : @"", comment ? comment : @""];
		}
	}
	
	[self _writeSettings:str];
}

- (void)_writeSettings:(NSString*)content
{
	NSString* dir = [Paths installedDir:@"settings"];
	NSString* path = [dir stringByAppendingPathComponent:@"styles.mimsy"];
	
	NSError* error = nil;
	[content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
	if (error)
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to write %@: %@", path, reason];
		[TranscriptController writeError:mesg];
	}
}

@end
