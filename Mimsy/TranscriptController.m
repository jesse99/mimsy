#import "TranscriptController.h"

#import "FunctionalTest.h"
#import "Paths.h"
#import "TextStyles.h"

static TranscriptController* controller;

@implementation TranscriptController
{
	NSDictionary* _infoAttrs;
	NSDictionary* _commandAttrs;
	NSDictionary* _stdoutAttrs;
	NSDictionary* _stderrAttrs;
	NSUInteger _editCount;
	double _maxChars;
}

- (id)init
{
	self = [super initWithWindowNibName:@"TranscriptWindow"];
	if (self)
	{
		_maxChars = INFINITY;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
	}
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	__weak id this = self;
	[self.view.textStorage setDelegate:this];
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

- (NSTextView*)getTextView
{
	return _view;
}

- (NSUInteger)getEditCount
{
	return _editCount;
}

- (NSArray*)getHelpContext
{
	return @[@"transcript"];
}

- (void)textStorageDidProcessEditing:(NSNotification*)notification
{
	UNUSED(notification);
	
	NSUInteger mask = self.view.textStorage.editedMask;
	if ((mask & NSTextStorageEditedCharacters))
	{
		_editCount++;
	}
}

- (void)clear:(id)sender
{
	(void) sender;
	
	NSRange range = NSMakeRange(0, self.view.textStorage.length);
	[self.view.textStorage deleteCharactersInRange:range];
	
	++_editCount;
}

+ (bool)empty
{
	TranscriptController* instance = [TranscriptController getInstance];
	return instance.view.textStorage.length == 0;
}

+ (void)writeInfo:(NSString*)text
{
    TranscriptController* instance = [TranscriptController getInstance];
    [instance _write:text withAttrs:instance->_infoAttrs];
}

+ (void)writeCommand:(NSString*)text
{
    TranscriptController* instance = [TranscriptController getInstance];
    [instance _write:text withAttrs:instance->_commandAttrs];
}

+ (NSRange)writeStderr:(NSString*)text
{
    TranscriptController* instance = [TranscriptController getInstance];
    return [instance _write:text withAttrs:instance->_stderrAttrs];
}

+ (void)writeStdout:(NSString*)text
{
    TranscriptController* instance = [TranscriptController getInstance];
    [instance _write:text withAttrs:instance->_stdoutAttrs];
}

+ (void)writeError:(NSString*)text
{
    LOG("Error", "%s", STR(text));
    
    if (!functionalTestsAreRunning())
    {
        TranscriptController* instance = [TranscriptController getInstance];
        [instance _write:[text stringByAppendingString:@"\n"] withAttrs:instance->_stderrAttrs];
    }
    else
    {
        NSString* str = [[NSString alloc] initWithString:[text stringByAppendingString:@"\n"]];
        recordFunctionalError(str);
    }
}

+ (NSMutableAttributedString*)getString
{
    TranscriptController* instance = [TranscriptController getInstance];
    return instance.view.textStorage;
}

+ (NSTextView*)getView
{
    TranscriptController* instance = [TranscriptController getInstance];
    return instance.view;
}

- (NSRange)_write:(NSString*)text withAttrs:(NSDictionary*)attrs
{
    NSRange range = NSMakeRange(0, 0);
    
    if (text.length > 0)
    {
        [self showWindow:nil];
        
        NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:text];
        [str setAttributes:attrs range:NSMakeRange(0, text.length)];
        
        [self _trimExtra];
        range = NSMakeRange(self.view.textStorage.length, text.length);
        
        [self.view.textStorage appendAttributedString:str];
        if (attrs == _stderrAttrs)
            [self.window makeKeyAndOrderFront:self];
        [self _scrollLastIntoView];
        self->_editCount += 1;
    }
    
    return range;
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
	TextStyles* styles = [[TextStyles new] initWithPath:path expectBackColor:true];
	_infoAttrs    = [styles attributesForElement:@"info"];
	_commandAttrs = [styles attributesForElement:@"command"];
	_stdoutAttrs  = [styles attributesForElement:@"stdout"];
	_stderrAttrs  = [styles attributesForElement:@"stderr"];
	
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
				if ([element isEqualToString:@"info"])
					[self.view.textStorage setAttributes:_infoAttrs range:range];
				
				else if ([element isEqualToString:@"command"])
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
		LOG("Error", "bad MaxChars: %s", STR(text));
		result = INFINITY;
	}
	
	return result;
}

@end
