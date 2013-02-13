#import "TranscriptController.h"

#import "FunctionalTest.h"
#import "Logger.h"
#import "Paths.h"
#import "TextStyles.h"

static TranscriptController* controller;

@implementation TranscriptController
{
	NSDictionary* _commandAttrs;
	NSDictionary* _stdoutAttrs;
	NSDictionary* _stderrAttrs;
	double _maxChars;
}

- (id)init
{
	self = [super initWithWindowNibName:@"Transcript"];
	if (self)
	{
		_maxChars = INFINITY;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
		[self showWindow:self];
	}
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

+ (TranscriptController*)getInstance
{
	if (controller == nil)
	{
		controller = [TranscriptController new];
		[controller _loadSettings];
	}
	
	return controller;
}

- (NSArray*)getHelpContext
{
	return @[@"transcript"];
}

- (void)clear:(id)sender
{
	(void) sender;
	
	NSRange range = NSMakeRange(0, self.view.textStorage.length);
	[self.view.textStorage deleteCharactersInRange:range];
}

+ (void)writeCommand:(NSString*)text
{
	TranscriptController* instance = [TranscriptController getInstance];
	NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:text];
	[str setAttributes:instance->_commandAttrs range:NSMakeRange(0, text.length)];
	[instance.view.textStorage appendAttributedString:str];
	[instance _trimExtra];
	[instance _scrollLastIntoView];
}

+ (void)writeStderr:(NSString*)text
{
	TranscriptController* instance = [TranscriptController getInstance];
	NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:text];
	[str setAttributes:instance->_stderrAttrs range:NSMakeRange(0, text.length)];
	[instance.view.textStorage appendAttributedString:str];
	[instance _trimExtra];
	[instance.window makeKeyAndOrderFront:self];
	[instance _scrollLastIntoView];
}

+ (void)writeStdout:(NSString*)text
{
	TranscriptController* instance = [TranscriptController getInstance];
	NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:text];
	[str setAttributes:instance->_stdoutAttrs range:NSMakeRange(0, text.length)];
	[instance.view.textStorage appendAttributedString:str];
	[instance _trimExtra];
	[instance _scrollLastIntoView];
}

+ (void)writeError:(NSString*)text
{
	LOG_ERROR("Transcript", "%s", STR(text));
	
	if (!functionalTestsAreRunning())
	{
		TranscriptController* instance = [TranscriptController getInstance];
		NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"]];
		[str setAttributes:instance->_stderrAttrs range:NSMakeRange(0, text.length)];
		[instance.view.textStorage appendAttributedString:str];
		[instance _trimExtra];
		[instance.window makeKeyAndOrderFront:self];
		[instance _scrollLastIntoView];
	}
	else
	{
		NSString* str = [[NSString alloc] initWithString:[text stringByAppendingString:@"\n"]];
		recordFunctionalError(str);
	}
}

- (void)settingsChanged:(NSNotification*)notification
{
	(void) notification;
	
	[self _loadSettings];
	[self _reapplyStyles];
}

- (void)_loadSettings
{
	NSString* dir = [Paths installedDir:@"settings"];
	NSString* path = [dir stringByAppendingPathComponent:@"transcript.rtf"];
	TextStyles* styles = [[TextStyles new] initWithPath:path];
	_commandAttrs = [styles attributesForElement:@"command"];
	_stdoutAttrs = [styles attributesForElement:@"stdout"];
	_stderrAttrs = [styles attributesForElement:@"stderr"];
	
	_maxChars = [self _parseNumber:[styles valueForKey:@"MaxChars"]];
	
	[self.view setBackgroundColor:styles.backColor];
}

- (void)_reapplyStyles
{
	NSRange full = NSMakeRange(0, self.view.textStorage.length);
	[self.view.textStorage enumerateAttribute:@"element name" inRange:full options:0 usingBlock:
		^(NSString* element, NSRange range, BOOL* stop)
		{
			(void) stop;
			if (element)
			{
				if ([element isEqualToString:@"command"])
					[self.view.textStorage setAttributes:_commandAttrs range:range];
				
				else if ([element isEqualToString:@"stdout"])
					[self.view.textStorage setAttributes:_stdoutAttrs range:range];
				
				else if ([element isEqualToString:@"stderr"])
					[self.view.textStorage setAttributes:_stderrAttrs range:range];
			}
		}
	 ];
}

- (void)_scrollLastIntoView
{
	NSRange range = NSMakeRange(self.view.textStorage.length, 0);
	[self.view scrollRangeToVisible:range];
}

- (void)_trimExtra
{
	if (self.view.textStorage.length >= 1.2*_maxChars)
	{
		NSRange range = NSMakeRange(0, (NSUInteger) (self.view.textStorage.length - _maxChars));
		[self.view.textStorage deleteCharactersInRange:range];
	}
}

- (double)_parseNumber:(NSString*)text
{
	double result;
	
	if ([text isEqualToString:@"infinity"])
	{
		result = INFINITY;
	}
	else if ([text hasSuffix:@"K"])
	{
		result = 1000*[text floatValue];
	}
	else if ([text hasSuffix:@"M"])
	{
		result = 1000*1000*[text floatValue];
	}
	else
	{
		result = [text floatValue];
	}
	
	if (result <= 0.0)
	{
		// It's either actually non-positive or malformed. In either case
		// there is a problem.
		LOG_ERROR("Transcript", "bad MaxChars: %s", STR(text));
		result = INFINITY;
	}
	
	return result;
}

@end
