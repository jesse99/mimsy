#import "TranscriptController.h"

#import "AppDelegate.h"
#import "Paths.h"
#import "TextStyles.h"

static TranscriptController* controller;
static NSMutableArray* startupErrors;

@implementation TranscriptController
{
	NSDictionary* _infoAttrs;
	NSDictionary* _commandAttrs;
	NSDictionary* _stdoutAttrs;
	NSDictionary* _stderrAttrs;
	NSUInteger _editCount;
	double _maxChars;
}

+ (void)startedUp
{
    if (startupErrors)
    {
        TranscriptController* instance = [TranscriptController getInstance];
        for (NSString* err in startupErrors)
        {
            [instance _write:[err stringByAppendingString:@"\n"] withAttrs:instance->_stderrAttrs];
        }
        startupErrors = nil;
    }
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

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processedEditing:) name:NSTextStorageDidProcessEditingNotification object:self.view.textStorage];
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

- (void)processedEditing:(NSNotification*)notification
{
	UNUSED(notification);
	
	NSUInteger mask = self.view.textStorage.editedMask;
	if ((mask & NSTextStorageEditedCharacters))
	{
		_editCount++;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TextWindowEdited" object:self];
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

- (void)write:(enum TranscriptStyle)style text:(NSString* __nonnull)text
{
    switch (style)
    {
        case TranscriptStyleInfo:
            [self _write:text withAttrs:_infoAttrs];
            break;
            
        case TranscriptStyleCommand:
            [self _write:text withAttrs:_commandAttrs];
            break;

        case TranscriptStyleStderr:
        case TranscriptStyleError:
            [self _write:text withAttrs:_stderrAttrs];
            break;

        default:
            [self _write:text withAttrs:_stdoutAttrs];
            break;
    }
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
    ASSERT([NSThread isMainThread]);    // otherwise we don't have a legit return value
    
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
    
    AppDelegate* delegate = (AppDelegate*) [NSApp delegate];
    if (!delegate || delegate.inited)
    {
        if (!startupErrors)
            startupErrors = [NSMutableArray new];

        [startupErrors addObject:text];
        return;
    }

    TranscriptController* instance = [TranscriptController getInstance];
    [instance _write:[text stringByAppendingString:@"\n"] withAttrs:instance->_stderrAttrs];
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
    if (![NSThread isMainThread])
    {
        dispatch_queue_t main = dispatch_get_main_queue();
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
        dispatch_after(delay, main, ^{
            [self _write:text withAttrs:attrs];
        });
        return NSMakeRange(0, 0);
    }
    
    NSRange range = NSMakeRange(0, 0);
    
    if (text.length > 0)
    {
        if (!self.window.isVisible)
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
	MimsyPath* dir = [Paths installedDir:@"settings"];
	MimsyPath* path = [dir appendWithComponent:@"transcript.rtf"];
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
            (void) range;
			if (element)
			{
				if ([element isEqualToString:@"info"])
                    [self.view.textStorage setAttributes:self->_infoAttrs range:range];
				
				else if ([element isEqualToString:@"command"])
                    [self.view.textStorage setAttributes:self->_commandAttrs range:range];
				
				else if ([element isEqualToString:@"stdout"])
                    [self.view.textStorage setAttributes:self->_stdoutAttrs range:range];
				
				else if ([element isEqualToString:@"stderr"])
                    [self.view.textStorage setAttributes:self->_stderrAttrs range:range];
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
