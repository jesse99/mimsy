#import "TextController.h"

#import "AppDelegate.h"
#import "ApplyStyles.h"
#import "Balance.h"
#import "ConfigParser.h"
#import "DirectoryController.h"
#import "FunctionalTest.h"
#import "GlyphsAttribute.h"
#import "IntegerDialogController.h"
#import "Language.h"
#import "Languages.h"
#import "MenuCategory.h"
#import "Paths.h"
#import "RangeVector.h"
#import "RestoreView.h"
#import "StartupScripts.h"
#import "TextView.h"
#import "TextDocument.h"
#import "TextStyles.h"
#import "TimeMachine.h"
#import "TranscriptController.h"
#import "UIntVectorUtils.h"
#import "Utils.h"
#import "WarningWindow.h"
#import "WindowsDatabase.h"
#import "Mimsy-Swift.h"

@implementation CharacterMapping
{
    NSString* _chars;
    bool _repeat;
}

- (id)initWith:(NSRegularExpression*)regex style:(NSString*)style chars:(NSString*)chars options:(enum MappingOptions)options controller:(TextController*)controller
{
    self = [super init];
    
    if (self)
    {
        _regex = regex;
        if (_regex.numberOfCaptureGroups > 1)
        {
            LOG("Plugins", "'%s' regex has more than one capture group", STR(_regex));
            return nil;
        }
        
        _style = [style lowercaseString];
        _chars = chars;
        _repeat = options == MappingOptionsUseGlyphsForEachChar;
        
        NSDictionary* style = [controller.styles attributesForElement:_style];
        _glyphs = [[GlyphsAttribute alloc] initWithStyle:style chars:_chars repeat:_repeat];
    }
    
    return self;
}

- (void)reload:(TextController*)controller
{
    NSDictionary* style = [controller.styles attributesForElement:_style];
    _glyphs = [[GlyphsAttribute alloc] initWithStyle:style chars:_chars repeat:_repeat];
}

@end

@implementation TextController 
{
	RestoreView* _restorer;
	bool _closed;
	bool _wordWrap;
	NSUInteger _editCount;
	Language* _language;
	TextStyles* _styles;
	ApplyStyles* _applier;
	NSMutableArray* _layoutBlocks;
	struct UIntVector _lineStarts;	// first index is at zero, other indexes are one past new-lines
    NSMutableArray* _mappings;
    Settings* _settings;
    
    int _showLeadingSpaces; // -1 == use app settings, 0 == off, 1 == on
    int _showLeadingTabs;
    int _showLongLines;
    int _showNonLeadingTabs;
}

static __weak TextController* _frontmost;

- (id<MimsyLanguage>)language
{
    return _language;
}

- (id<MimsyProject> __nullable)project
{
    return [DirectoryController getController:self.path];
}

- (NSTextView* _Nonnull)view
{
    return self.textView;
}

- (NSString* _Nonnull)string
{
    return self.text;
}

- (NSRange)selectionRange
{
    return self.textView.selectedRange;
}

- (void)setSelectionRange:(NSRange)range
{
    [self.textView setSelectedRange:range];
}

- (NSString*)selection
{
    NSRange range = self.textView.selectedRange;
    return [self.textView.string substringWithRange:range];
}

- (void)setSelection:(NSString * __nonnull)text undoText:(NSString * __nonnull)undoText
{
    NSRange range = self.textView.selectedRange;
    [self setText:text forRange:range undoText:undoText];
}

- (void)setText:(NSString * __nonnull)text undoText:(NSString * __nonnull)undoText
{
    NSRange range = NSMakeRange(0, self.text.length);
    [self setText:text forRange:range undoText:undoText];
}

- (void)setText:(NSString *)text forRange:(NSRange)forRange undoText:(NSString *)undoText
{
    if ([self.textView shouldChangeTextInRange:forRange replacementString:text])
    {
        [self.textView replaceCharactersInRange:forRange withString:text];
        [self.textView.undoManager setActionName:undoText];
        [self.textView didChangeText];
    }
}

- (void)addMapping:(NSRegularExpression * __nonnull)regex style:(NSString * __nonnull)style chars:(NSString * __nonnull)chars options:(enum MappingOptions)options
{
    CharacterMapping* mapping = [[CharacterMapping alloc] initWith:regex style:style chars:chars options:options controller:self];

    for (NSUInteger i = 0; i < _mappings.count; ++i)
    {
        CharacterMapping* candidate = _mappings[i];
        if ([candidate.regex isEqual:regex])
        {
            _mappings[i] = mapping;
            if (_applier)
                [_applier addDirtyLocation:0 reason:@"new mapping"];
            return;
        }
    }

    [_mappings addObject:mapping];
    if (_applier)
        [_applier addDirtyLocation:0 reason:@"new mapping"];
}

- (void)removeMapping:(NSRegularExpression * __nonnull)regex
{
    for (NSUInteger i = 0; i < _mappings.count; ++i)
    {
        CharacterMapping* mapping = _mappings[i];
        if ([mapping.regex isEqual:regex])
        {
            [_mappings removeObjectAtIndex:i];
            if (_applier)
                [_applier addDirtyLocation:0 reason:@"removed mapping"];
            break;
        }
    }
}

- (bool)closed
{
    return _closed;
}

+ (void)_addTextViewItem:(NSString*)title selector:(SEL)selector
{
    AppDelegate* app = [NSApp delegate];
    NSMenu* menu = app.textMenu;
    if (menu)
    {
        NSInteger index = [menu indexOfItemWithTag:1];
        
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:@""];
        [menu insertSortedItem:item atIndex:index+1];
    }
}

- (void)_toggleLeadingSpaces:(id)sender
{
    UNUSED(sender);
    
    if (_showLeadingSpaces < 1)
        _showLeadingSpaces = 1;
    else
        _showLeadingSpaces = 0;
    
    if (_applier)
        [_applier addDirtyLocation:0 reason:@"show leading spaces changed"];
}

- (void)_toggleLeadingTabs:(id)sender
{
    UNUSED(sender);
    
    if (_showLeadingTabs < 1)
        _showLeadingTabs = 1;
    else
        _showLeadingTabs = 0;
    
    if (_applier)
        [_applier addDirtyLocation:0 reason:@"show leading tabs changed"];
}

- (void)_toggleLongLines:(id)sender
{
    UNUSED(sender);
    
    if (_showLongLines < 1)
        _showLongLines = 1;
    else
        _showLongLines = 0;
    
    if (_applier)
        [_applier addDirtyLocation:0 reason:@"show long lines changed"];
}

- (void)_toggleNonLeadingTabs:(id)sender
{
    UNUSED(sender);
    
    if (_showNonLeadingTabs < 1)
        _showNonLeadingTabs = 1;
    else
        _showNonLeadingTabs = 0;

    if (_applier)
        [_applier addDirtyLocation:0 reason:@"show non-leading tabs changed"];
}

- (bool)showingLeadingSpaces
{
    if (_applier)
        if (_showLeadingSpaces == -1)
            return [_settings boolValue:@"ShowLeadingSpaces" missing:false];
        else
            return _showLeadingSpaces;
    else
        return false;
}

- (bool)showingLeadingTabs
{
    if (_applier)
        if (_showLeadingTabs == -1)
            return [_settings boolValue:@"ShowLeadingTabs" missing:false];
        else
            return _showLeadingTabs;
    else
        return false;
}

- (bool)showingLongLines
{
    if (_applier)
        if (_showLongLines == -1)
            return [_settings boolValue:@"ShowLongLines" missing:false];
        else
            return _showLongLines;
    else
        return false;
}

- (bool)showingNonLeadingTabs
{
    if (_applier)
        if (_showNonLeadingTabs == -1)
            return [_settings boolValue:@"ShowNonLeadingTabs" missing:false];
        else
            return _showNonLeadingTabs;
    else
        return false;
}

- (id)init
{
    self = [super initWithWindowNibName:@"TextDocument"];
    if (self)
	{
		[self setShouldCascadeWindows:NO];

		// This will be set to nil once the view has been restored.
		_restorer = [[RestoreView alloc] init:self];
		_styles = [self _createDefaultTextStyles];
		
		_layoutBlocks = [NSMutableArray new];
		_lineStarts = newUIntVector();
        _mappings = [NSMutableArray new];
        
        _showLeadingSpaces = -1; // -1 == use app settings, 0 == off, 1 == on
        _showLeadingTabs = -1;
        _showLongLines = -1;
        _showNonLeadingTabs = -1;
        _settings = [[Settings alloc] init:@"untitled" context:self];
        
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languagesChanged:) name:@"LanguagesChanged" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stylesChanged:) name:@"StylesChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_mainChanged:) name:NSWindowDidBecomeMainNotification object:nil];
	}
    
	return self;
}

- (void)dealloc
{
	freeUIntVector(&_lineStarts);
}

- (void)windowDidLoad
{
    __weak id this = self;
    [self.textView setDelegate:this];
    [self.textView.textStorage setDelegate:this];
    [self.textView.layoutManager setDelegate:this];
    [self.textView.layoutManager setBackgroundLayoutEnabled:YES];
    
    NSRect frame = self.window.frame;
    int width = [_settings intValue:@"DefaultWindowWidth" missing:0];
    int height = [_settings intValue:@"DefaultWindowHeight" missing:0];
    if (width)
        frame.size.width = width;
    if (height)
        frame.size.height = height;
    if (width || height)
        [[self window] setFrame:frame display:true];
    
    [super windowDidLoad];
	[self.document controllerDidLoad];
	[self.textView onOpened:self];

	if (!_language)
	{
		NSDocument* doc = self.document;
		if ([doc.fileType contains:@"Plain Text"] || [doc.fileType isEqualToString:@"binary"])
			[self.textView setBackgroundColor:_styles.backColor];
	}
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processedEditing:) name:NSTextStorageDidProcessEditingNotification object:self.textView.textStorage];
}

- (id<SettingsContext>)parent
{
    DirectoryController* controller = [DirectoryController getController:self.path];
    if (controller)
        return controller;
    
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    return app;
}

- (Settings*)settings
{
    return _settings;
}

- (void)registerBlockWhenLayoutCompletes:(LayoutCallback)block
{
	[_layoutBlocks addObject:block];
}

- (void)windowWillClose:(NSNotification*)notification
{
	UNUSED(notification);
	
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"TextWindowClosing" object:self];
	
	_closed = true;
    
	NSString* path = [self path];
	if (path)
	{
		// If the document has changes but is not being saved then we don't
		// want to persist this information because it will likely be wrong when
		// the old text is loaded.
		if (![self.document isDocumentEdited])
		{
			NSScrollView* sv = self.scrollView;
			
			struct WindowInfo info;
			info.length    = (NSInteger) self.text.length;
			info.origin    = sv ? sv.contentView.bounds.origin : NSZeroPoint;
			info.selection = self.textView.selectedRange;
			info.wordWrap  = self->_wordWrap;
			NSRect frame = self.window.frame;
			[WindowsDatabase saveInfo:&info frame:frame forPath:path];
		}
		
//		if (Path.Contains("/var/") && Path.Contains("/-Tmp-/"))		// TODO: seems kind of fragile, maybe we should have a Mimsy specific tmp directory
//			DoDeleteFile(Path);
	}
	
	// If the windows are closed very very quickly and we don't do this
	// we get a crash when Cocoa tries to call our delegate.
	[self.textView.layoutManager setDelegate:nil];
}

- (NSString*)getElementNames
{
    NSMutableString* text = [NSMutableString new];

    if (_language)
	{
        __block NSInteger currentIndex = -1;
        __block struct RangeVector ranges = newRangeVector();
        __block NSMutableArray* names = [NSMutableArray new];
        
		NSAttributedString* str = self.textView.textStorage;
		NSRange currentRange = self.textView.selectedRange;
		[str enumerateAttribute:@"element name" inRange:NSMakeRange(0, str.length) options:0 usingBlock:^(NSString* value, NSRange range, BOOL *stop) {
			UNUSED(stop);
			[names addObject:value];
			pushRangeVector(&ranges, range);
			
			if (currentIndex < 0 && currentRange.location >= range.location && currentRange.location+currentRange.length <= range.location+range.length)
				currentIndex = (int) names.count - 1;
		}];
        
        text = [NSMutableString stringWithCapacity:names.count*(6+1 + 3+1 + 2+1)];
        [text appendFormat:@"%ld\n", (long)currentIndex];
        
        for (NSUInteger i = 0; i < names.count; ++i)
        {
            [text appendFormat:@"%@\f%lu\f%lu\n", names[i], (unsigned long)ranges.data[i].location, (unsigned long)ranges.data[i].length];
        }
        
        freeRangeVector(&ranges);
	}
	
	return text;
}

- (NSString*)getElementNameFor:(NSRange)range
{
	NSString* element = nil;
	
	if (_language)
	{
		NSAttributedString* str = self.textView.textStorage;
		NSDictionary* attrs = [str attributesAtIndex:range.location longestEffectiveRange:NULL inRange:range];
		element = attrs ? attrs[@"element name"] : nil;
	}
	
	return element;
}

- (void)open
{
	if (self.path)
		LOG("Text", "Window for %s opened", STR([self.path lastPathComponent]));
	else
		LOG("Text", "Untitled window opened");
		
	[self.window makeKeyAndOrderFront:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TextWindowOpened" object:self];
	
	// TODO: need to do this stuff
	//Broadcaster.Invoke("opened document window", m_boss);
	//synchronizeWindowTitleWithDocumentName();		// bit of a hack, but we need something like this for IDocumentWindowTitle to work

	//DoSetTabSettings();
}

- (NSString*)windowTitleForDocumentDisplayName:(NSString*)displayName
{
	if (self.customTitle)
		return self.customTitle;
	else
		return [super windowTitleForDocumentDisplayName:displayName];
}

- (NSTextView*)getTextView
{
	return _textView;
}

- (NSUInteger)getEditCount
{
	return _editCount;
}

- (bool)canBalanceIndex:(NSUInteger)index
{
	bool can = true;
	
	if (_language)
	{
		NSString* element = [self getElementNameFor:NSMakeRange(index, 1)];
		can = element == nil || (
			[@"DocComment" caseInsensitiveCompare:element] != NSOrderedSame &&
			[@"LineComment" caseInsensitiveCompare:element] != NSOrderedSame &&
			[@"Comment" caseInsensitiveCompare:element] != NSOrderedSame &&
			[@"String" caseInsensitiveCompare:element] != NSOrderedSame &&
			[@"Character" caseInsensitiveCompare:element] != NSOrderedSame);
	}
	
	return can;
}

- (bool)isBrace:(unichar)ch
{
	return ch == '(' || ch == '[' || ch == '{' || (ch == ')' || ch == ']' || ch == '}');	
}

- (bool)isOpenBrace:(NSUInteger)index
{
	unichar ch = [self.text characterAtIndex:index];
	return (ch == '(' || ch == '[' || ch == '{') && [self canBalanceIndex:index];
}

- (bool)isCloseBrace:(NSUInteger)index
{
	unichar ch = [self.text characterAtIndex:index];
	return (ch == ')' || ch == ']' || ch == '}') && [self canBalanceIndex:index];
}

- (void)balance:(id)sender
{
	UNUSED(sender);
	
	NSString* text = self.textView.textStorage.string;
	NSRange originalRange = self.textView.selectedRange;
	
	NSRange range = balance(text, originalRange, ^(NSUInteger index){return [self isOpenBrace:index];}, ^(NSUInteger index){return [self isCloseBrace:index];});
	
	// If we get the same range back then try for a larger range.
	if (range.length > 2 && range.location + 1 == originalRange.location && range.length - 2 == originalRange.length)
		range = balance(text, range, ^(NSUInteger index){return [self isOpenBrace:index];}, ^(NSUInteger index){return [self isCloseBrace:index];});
	
	if (range.length > 2)
		[self.textView setSelectedRange:NSMakeRange(range.location + 1, range.length - 2)];
	else if (range.length > 0)
		[self.textView setSelectedRange:range];
	else
		NSBeep();
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	BOOL enabled = NO;
	
	SEL sel = [item action];
	if (sel == @selector(shiftLeft:) || sel == @selector(shiftRight:))
	{
		NSRange range = self.textView.selectedRange;
		enabled = range.length > 0 && self.textView.isEditable;
	}
    else if (sel == @selector(toggleComment:))
    {
        enabled = _language != nil && _language.lineComment != nil;
    }
    else if (sel == @selector(_toggleLeadingSpaces:))
    {
        [item setTitle:self.showingLeadingSpaces ? @"Hide Leading Spaces" : @"Show Leading Spaces"];
        enabled = _applier != nil;
    }
    else if (sel == @selector(_toggleLeadingTabs:))
    {
        [item setTitle:self.showingLeadingTabs ? @"Hide Leading Tabs" : @"Show Leading Tabs"];
        enabled = _applier != nil;
    }
    else if (sel == @selector(_toggleLongLines:))
    {
        [item setTitle:self.showingLongLines ? @"Hide Long Lines" : @"Show Long Lines"];
        enabled = _applier != nil;
    }
    else if (sel == @selector(_toggleNonLeadingTabs:))
	{
        [item setTitle:self.showingNonLeadingTabs ? @"Hide Non-leading Spaces" : @"Show Non-leading Spaces"];
        enabled = _applier != nil;
	}
	else if ([self respondsToSelector:sel])
	{
		enabled = YES;
	}
	else if ([super respondsToSelector:@selector(validateMenuItem:)])
	{
		enabled = [super validateMenuItem:item];
	}
	
	return enabled;
}

- (void)removeStyle:(id)sender
{
	UNUSED(sender);

	// It's a little goofy to support the font menu items for files with a
	// language, but it can be kind of nice to support at least some of them.
	// For example, making some text temporarily larger or what have you.
    NSDictionary* attrs = [_styles attributesForElement:@"normal"];
	NSRange range = self.textView.selectedRange;
	if (range.length > 0)
	{
		if ([self.textView shouldChangeTextInRange:range replacementString:nil])
		{
			NSTextStorage* storage = self.textView.textStorage;
            [storage setAttributes:attrs range:range];
			[self.textView didChangeText];
		}
	}
	else
	{
        [self.textView setTypingAttributes:attrs];
	}
}

+ (TextController*)frontmost
{
    TextController* controller = _frontmost;
    return controller;
}

+ (void)enumerate:(void (^)(TextController*, bool*))block
{
	bool stop = false;
	for (NSWindow* window in [NSApp orderedWindows])
	{
		if (window.isVisible || window.isMiniaturized)
			if (window.windowController)
				if ([window.windowController isKindOfClass:[TextController class]])
				{
					block(window.windowController, &stop);
					if (stop)
						break;
				}
	}
}

+ (TextController*)find:(NSString*)path
{
	for (NSWindow* window in [NSApp orderedWindows])
	{
		if (window.isVisible || window.isMiniaturized)
		{
			if (window.windowController)
			{
				if ([window.windowController isKindOfClass:[TextController class]])
				{
					TextController* controller = window.windowController;
					if (controller.path && [controller.path compare:path] == NSOrderedSame)
						return controller;
				}
			}
		}
	}
	
	return nil;
}

- (NSArray*)getHelpContext
{
	NSMutableArray* result = [NSMutableArray new];
	
	if (_language)
		[result addObject:_language.name];
	
	NSString* path = [self path];
	if (path)
	{
		[self _addInstalledContexts:result forPath:path];
#if OLD_EXTENSIONS
		addFunctionalTestHelpContext(result, path);
#endif
	}
	
	[result addObject:@"text editor"];
	
	return result;
}

- (void)_addInstalledContexts:(NSMutableArray*)result forPath:(NSString*)path
{
	NSString* dir = [Paths installedDir:nil];
	if (dir && ![dir hasSuffix:@"/"])
		dir = [dir stringByAppendingString:@"/"];
	
	if ([path hasPrefix:dir])
	{
		NSString* name = [path substringFromIndex:dir.length];
		NSArray* parts = [name pathComponents];
		if (parts.count > 1)
		{
			[result addObject:parts[0]];
		}
	}
}

- (NSArray*) charMappings
{
    return _mappings;
}

- (NSAttributedString*)attributedText
{
	return self.textView.textStorage;
}

- (void)resetStyles
{
	if (_applier)
		[_applier addDirtyLocation:0 reason:@"resetStyles"];
}

- (void)setAttributedText:(NSAttributedString*)text
{
	_editCount++;
	[self.textView.textStorage setAttributedString:text];
	[self resetTextAttributes];
	if (_applier)
		[_applier addDirtyLocation:0 reason:@"set text"];
}

- (NSString*)text
{
	return [[self.textView textStorage] string];
}

- (Language*)fullLanguage
{
	return _language;
}

- (NSString*)_getDefaultStyleName
{
	NSString* name = nil;
	
	NSString* dir = [Paths installedDir:@"settings"];
	NSString* path = [dir stringByAppendingPathComponent:@"styles.mimsy"];
	
	NSError* error = nil;
	ConfigParser* parser = [[ConfigParser alloc] initWithPath:path outError:&error];
	if (parser)
	{
		name = [parser valueForKey:@"Default"];
		if (!name)
		{
			NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't find Default key in %@:\n", path];
			[TranscriptController writeError:mesg];
		}
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load %@:\n%@", path, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
	}
	
	if (!name)
		name = @"mimsy/pastel-proportional.rtf";
	
	return name;
}

- (void)setLanguage:(Language*)lang
{
	if (lang != _language)
	{
		_language = lang;
		LOG("Text:Verbose", "Set language for %s to %s", STR([self.path lastPathComponent]), STR(lang));
        
        // TODO: Might want to support per-file settings (though that doesn't seem terribly useful).
        _settings = [[Settings alloc] init:self.path.lastPathComponent context:self];
		if (_language)
        {
            for (NSUInteger i = 0; i < _language.settingKeys.count; i++)
            {
                [_settings addKey:_language.settingKeys[i] value:_language.settingValues[i]];
            }
			_styles = [self _createTextStyles];
        }
		else
			_styles = [self _createDefaultTextStyles];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsChanged" object:self];

		if (_language && !_applier)
			_applier = [[ApplyStyles alloc] init:self];
		else if (!_language && _applier)
			_applier = nil;
		
		[self resetTextAttributes];
		if (_applier)
			[_applier addDirtyLocation:0 reason:@"set language"];
		
		[self _resetAutomaticSubstitutions];
	}
}

- (void)_resetAutomaticSubstitutions
{
	NSDocument* doc = self.document;
	NSString* type = doc.fileType;
	bool enable = _language == nil && ![type contains:@"Plain Text"] && ![type isEqualToString:@"binary"] && [_settings boolValue:@"EnableSubstitutions" missing:true];
	[self.textView setAutomaticQuoteSubstitutionEnabled:enable];
	[self.textView setAutomaticDashSubstitutionEnabled:enable];
	[self.textView setAutomaticTextReplacementEnabled:enable];
}

- (void)languagesChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
    if (_language)
    {
        _settings = [[Settings alloc] init:self.path.lastPathComponent context:self];
		[self setLanguage:[Languages findWithlangName:_language.name]];
    }
}

- (void)stylesChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
	if (_language)
	{
        for (CharacterMapping* mapping in _mappings)
        {
            [mapping reload:self];
        }

        _styles = [[TextStyles alloc] initWithPath:_styles.path expectBackColor:true];
		if (_applier)
			[_applier resetStyles];
	}
}

- (void)settingsChanged:(NSNotification*)notification
{
    id object = notification.object;
	
    if (object != [Settings class]) // don't do anything if only the window order has changed
    {
        [self resetTextAttributes];
        [self _resetAutomaticSubstitutions];
        if (_applier)
            [_applier addDirtyLocation:0 reason:@"settings changed"];
    }
}

- (void)changeStyle:(NSString*)path
{
	assert(_language);
	_styles = [[TextStyles alloc] initWithPath:path expectBackColor:true];
	if (_applier)
		[_applier resetStyles];
}

- (NSString* _Nullable)path
{
	NSURL* url = [self.document fileURL];
    return url ? [url path] : nil;
}

- (void)_positionWindow:(NSString*)path
{
	NSRect frame = [WindowsDatabase getFrame:path];
	if (NSWidth(frame) >= 40)
	{
		[self.window setFrame:frame display:YES];	// note that Cocoa will ensure that windows with title bars are not moved off screen
	}
	else
	{
		TextController* front = [TextController frontmost];
		if (front)
		{
			NSPoint loc = [front.window cascadeTopLeftFromPoint:NSZeroPoint];
			[self.window cascadeTopLeftFromPoint:loc];
		}
	}	
}

- (void)onPathChanged
{
	NSString* path = [self path];
    NSDocument* doc = self.document;
	if (path)
	{
		[self _positionWindow:path];
        _settings = [[Settings alloc] init:path.lastPathComponent context:self];
		
		NSString* name = [path lastPathComponent];
        if ([doc.fileType isEqualToString:@"binary"])
            self.language = [Languages findWithlangName:@"binary"];
        else
            self.language = [Languages findWithFileName:name contents:self.text];
		
		if (_restorer)
			[_restorer setPath:path];
		if (_applier)
			[_applier addDirtyLocation:0 reason:@"path changed"];
		
		if (!_wordWrap)
			[self doResetWordWrap];

		if ([TimeMachine isSnapshotFile:self.path])
		{
			NSString* label = [TimeMachine getSnapshotLabel:path];
			NSString* title = [NSString stringWithFormat:@"%@ (from %@)", path.lastPathComponent, label];
			self.customTitle = title;
			[self synchronizeWindowTitleWithDocumentName];
		}
	}

    [self resetTextAttributes];
	if (!_language)
	{
		if ([doc.fileType contains:@"Plain Text"] || [doc.fileType isEqualToString:@"binary"])
        {
            NSDictionary* attrs = [_styles attributesForElement:@"normal"];
			[self.textView.textStorage setAttributes:attrs range:NSMakeRange(0, self.textView.textStorage.length)];
            [self.textView setTypingAttributes:attrs];
        }
	}

	[self _resetAutomaticSubstitutions];
}

// Should be called after anything that might change attributes.
- (NSDictionary*)resetTypingAttributes
{
    NSMutableDictionary* typingAttributes = nil;

    // If we don't have a language we'll leave whatever the user is
    // using alone (i.e. we only set styles for a document without
    // a language when we first open it).
    if (_language)
    {
        // Create paragraph attributes for the tab width.
        NSDictionary* attrs = [_styles attributesForElement:@"normal"];
        NSAttributedString* str = [[NSAttributedString alloc] initWithString:@" " attributes:attrs];
        double charWidth = str.size.width;
        int tabWidth = [_settings intValue:@"TabWidth" missing:4];
        tabWidth = [_settings intValue:@"DisplayTabWidth" missing:tabWidth];
        
        NSMutableParagraphStyle* paragraphStyle = [[self.textView defaultParagraphStyle] mutableCopy];
        if (!paragraphStyle)
            paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [paragraphStyle setDefaultTabInterval:tabWidth*charWidth];
        [paragraphStyle setTabStops:[NSArray array]];
        [self.textView setDefaultParagraphStyle:paragraphStyle];
        
        // Set the typing style to the normal style plus the paragraph attributes from above.
        typingAttributes = [attrs mutableCopy];
        [typingAttributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
        [self.textView setTypingAttributes:typingAttributes];
    }
    
    return typingAttributes;
}

- (void)resetTextAttributes
{
	if (_language)
    {
        NSDictionary* typingAttributes = [self resetTypingAttributes];

        NSRange range = NSMakeRange(0, self.textView.string.length);
//        [self.textView shouldChangeTextInRange:range replacementString:nil];
        [[self.textView textStorage] addAttributes:typingAttributes range:range];
//       [self.textView didChangeText];
    }
}

- (void)toggleComment:(id)sender
{
	UNUSED(sender);
	
	NSRange range = self.textView.selectedRange;
	NSUInteger firstLine = [self _offsetToLine:range.location];
	NSUInteger lastLine = [self _offsetToLine:range.location + range.length - 1];
	
	NSString* comment = _language.lineComment;
	
	NSUInteger offset = [self _lineToOffset:firstLine];
	bool add = ![self _textAt:offset matches:comment];
	
	NSArray* args = @[@(firstLine), @(lastLine), comment, @(add)];
	[self _toggleComment:args];
}

- (void)_toggleComment:(NSArray*)args
{
	NSUInteger firstLine = [((NSNumber*) args[0]) unsignedIntegerValue];
	NSUInteger lastLine = [((NSNumber*) args[1]) unsignedIntegerValue];
	NSString* comment = args[2];
	bool add = [((NSNumber*) args[3]) boolValue];
	
	NSTextStorage* storage = _textView.textStorage;
	[storage beginEditing];
	for (NSUInteger line = lastLine; line >= firstLine && line <= lastLine; --line)
	{
		NSUInteger offset = [self _lineToOffset:line];
		if (add)
		{
			if (![self _textAt:offset matches:comment])
				[storage replaceCharactersInRange:NSMakeRange(offset, 0) withString:comment];
		}
		else
		{
			if ([self _textAt:offset matches:comment])
				[storage deleteCharactersInRange:NSMakeRange(offset, comment.length)];
		}
	}
	[storage endEditing];
	
	NSUInteger firstOffset = [self _lineToOffset:firstLine];
	NSUInteger lastOffset = [self _lineToOffset:lastLine+1];
	[self.textView setSelectedRange:NSMakeRange(firstOffset, lastOffset - firstOffset)];
	
	NSArray* oldArgs = @[args[0], args[1], args[2], @(!add)];
	NSWindowController* controller = self.window.windowController;
	NSDocument* doc = controller.document;
	[doc.undoManager registerUndoWithTarget:self selector:@selector(_toggleComment:) object:oldArgs];
	[doc.undoManager setActionName:@"Toggle Comment"];
}

- (void)shiftLeft:(id)sender
{
	UNUSED(sender);
	
	NSRange range = self.textView.selectedRange;
	NSUInteger firstLine = [self _offsetToLine:range.location];
	NSUInteger lastLine = [self _offsetToLine:range.location + range.length - 1];
	
	NSArray* args = @[@(firstLine), @(lastLine), @(-1)];
	[self _shiftLines:args];
}

- (void)shiftRight:(id)sender
{
	UNUSED(sender);
	
	NSRange range = self.textView.selectedRange;
	NSUInteger firstLine = [self _offsetToLine:range.location];
	NSUInteger lastLine = [self _offsetToLine:range.location + range.length - 1];
	
	NSArray* args = @[@(firstLine), @(lastLine), @(+1)];
	[self _shiftLines:args];
}

- (void)_shiftLines:(NSArray*)args
{
	NSUInteger firstLine = [((NSNumber*) args[0]) unsignedIntegerValue];
	NSUInteger lastLine = [((NSNumber*) args[1]) unsignedIntegerValue];
	int delta = [((NSNumber*) args[2]) intValue];
	
	NSString* tab;
//	if (Language != null && !UsesTabs && !NSObject.IsNullOrNil(SpacesText))
//		tab = SpacesText;
//	else
		tab = @"\t";
	
	NSTextStorage* storage = self.textView.textStorage;
	[storage beginEditing];
	for (NSUInteger line = lastLine; line >= firstLine && line <= lastLine; --line)
	{
		NSUInteger offset = [self _lineToOffset:line];
		if (delta > 0)
		{
			[storage replaceCharactersInRange:NSMakeRange(offset, 0) withString:tab];
		}
		else
		{
			unichar ch = [storage.string characterAtIndex:offset];
			if (ch == '\t' || ch == ' ')	// need to stop shifting lines left when there is no more whitespace
			{
				[storage deleteCharactersInRange:NSMakeRange(offset, 1)];
			}
		}
	}
	[storage endEditing];
	
	NSUInteger firstOffset = [self _lineToOffset:firstLine];
	NSUInteger lastOffset = [self _lineToOffset:lastLine+1];
	[self.textView setSelectedRange:NSMakeRange(firstOffset, lastOffset - firstOffset)];
	
	NSArray* oldArgs = @[args[0], args[1], @(-delta)];
	NSWindowController* controller = self.window.windowController;
	NSDocument* doc = controller.document;
	[doc.undoManager registerUndoWithTarget:self selector:@selector(_shiftLines:) object:oldArgs];
	[doc.undoManager setActionName:@"Shift Lines"];
}

+ (NSUInteger)getOffset:(NSString*) text atLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)tabWidth
{
    ASSERT(line >= 1);
    ASSERT(col == -1 || col >= 1);
    ASSERT(tabWidth >= 1);
    
    NSUInteger begin = [TextController _getOffset:text atLine:line-1];
    
    NSInteger c = col - 1;
    while (begin < text.length && c > 0)
    {
        if ([text characterAtIndex:begin] == '\t')
            c -= tabWidth;
        else
            c -= 1;
        
        ++begin;
    }
    
    return begin;
}

// TODO: may want to maintain a line offset table
+ (NSUInteger)_getOffset:(NSString*) text atLine:(NSInteger)forLine
{
    NSUInteger offset = 0;
    NSInteger line = 0;
    
    while (line < forLine && offset < text.length)
    {
        if (offset + 1 < text.length && [text characterAtIndex:offset] == '\r' && [text characterAtIndex:offset+1] == '\n')
        {
            ++offset;
            ++line;
        }
        else if ([text characterAtIndex:offset] == '\r' || [text characterAtIndex:offset] == '\n')
        {
            ++line;
        }
        
        ++offset;
    }
    
    return offset;
}

- (void)jumpToLine:(id)sender
{
    UNUSED(sender);
    
    IntegerDialogController* controller = [[IntegerDialogController alloc] initWithTitle:@"Jump to Line" value:1];
    (void) [NSApp runModalForWindow:controller.window];
    
    if (controller.hasValue)
    {
        [self showLine:controller.textField.integerValue atCol:-1 withTabWidth:1];
    }
}

- (void)showLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)tabWidth
{
    ASSERT(line >= 1);
    ASSERT(col == -1 || col >= 1);
    ASSERT(tabWidth >= 1);
    
    NSString* text = self.text;
    
    NSUInteger begin = [TextController getOffset:text atLine:line atCol:col withTabWidth:tabWidth];
    NSUInteger end = [TextController _getOffset:text atLine:line];
    
    if (begin > end)		// may happen if the line was edited
    {
        end = begin;
        col = -1;
    }
    
    begin = MIN(begin, text.length);
    
    NSUInteger count = 1;	// it looks kind of stupid to animate the entire line so we find a range of similar text to hilite
    if (col > 0)
    {
        // Continuum, to a first approximation, skipped count characters that had
        // the same unicode character category. But that seems overkill and we'd
        // have to pull in ICU to do the same.
        NSCharacterSet* alphaNum = [NSCharacterSet alphanumericCharacterSet];
        while (begin + count < text.length && [alphaNum characterIsMember:[text characterAtIndex:begin+count]])
            ++count;
    }
    else
    {
        NSCharacterSet* newLines = [NSCharacterSet whitespaceCharacterSet];
        NSRange range = [text rangeOfCharacterFromSet:newLines options:0 range:NSMakeRange(begin, text.length - begin)];
        if (range.location != NSNotFound)
            count = range.location - begin;
    }
    
    [self _showLine:begin end:end count:count];
}

- (void)_showLine:(NSUInteger)begin end:(NSUInteger)end count:(NSUInteger)count
{
    if (_restorer)
    {
        [_restorer showLineBegin:begin end:end count:count];
    }
    else
    {
        [_textView setSelectedRange:NSMakeRange(begin, 0)];
        [_textView scrollRangeToVisible:NSMakeRange(begin, end - begin)];
        [_textView showFindIndicatorForRange:NSMakeRange(begin, count)];
    }
}

- (bool)isWordWrapping
{
	return _wordWrap;
}

- (void)toggleWordWrap
{
	_wordWrap = !_wordWrap;
	[self doResetWordWrap];
}

- (void)onAppliedStyles
{
    [self.declarationsPopup onAppliedStyles:self.textView];
    
    AppDelegate* app = [NSApp delegate];
    [app invokeTextViewHook:TextViewNotificationAppliedStyles view:self];
}

- (void)doResetWordWrap
{
	// This code is a bit weird and rather delicate:
	// 1) The container needs to be sized to the scroll view not the text view.
	// 2) sizeToFit must be called for some reason.
	// If this is not done the text (usually) does not wrap.
	if (_wordWrap)
	{
		NSScrollView* tmp = _scrollView;
		if (tmp)
		{
			NSSize contentSize = tmp.contentView.bounds.size;
			[_textView.textContainer setContainerSize:NSMakeSize(contentSize.width, HUGE_VAL)];
			[_textView.textContainer setWidthTracksTextView:YES];
		}
	}
	else
	{
		[_textView.textContainer setContainerSize:NSMakeSize(HUGE_VAL, HUGE_VAL)];
		[_textView.textContainer setWidthTracksTextView:NO];
	}
	
	[_textView sizeToFit];
}

- (void)textViewDidChangeSelection:(NSNotification*)notification
{
	UNUSED(notification);
	
	NSRange range = _textView.selectedRange;
	if (range.length == 0)
	{
		bool indexIsOpenBrace, indexIsCloseBrace, foundOtherBrace;
		NSUInteger index = tryBalance(_textView.textStorage.string, range.location, &indexIsOpenBrace, &indexIsCloseBrace, &foundOtherBrace, ^(NSUInteger index){return [self isOpenBrace:index];}, ^(NSUInteger index){return [self isCloseBrace:index];});
		
		if (indexIsOpenBrace)
			[_applier toggleBraceHighlightFrom:range.location-1 to:index on:foundOtherBrace];
		else
			[_applier toggleBraceHighlightFrom:index to:range.location on:foundOtherBrace];
	}
	else
	{
		[_applier toggleBraceHighlightFrom:0 to:0 on:false];
	}
	
    [self _updateLineNumberButton];
    [_declarationsPopup onSelectionChanged:self.textView];

#if OLD_EXTENSIONS
	[StartupScripts invokeTextSelectionChanged:self.document slocation:range.location slength:range.length];
#endif

    AppDelegate* app = [NSApp delegate];
    [app invokeTextViewHook:TextViewNotificationSelectionChanged view:self];
}

// editedRange is the range of the new text. For example if a character
// is typed it will be the range of the new character, if text is pasted it
// will be the range of the inserted text.
//
// changeInLength is the difference in length between the old selection
// and the new text.
//
// Note that this is called for every key stroke. Also note that editedRange
// isn't a very reliable way to determine the number of characters edited
// (often attribute edits are merged in, not sure from where and it's not
// via the _applier but they seem to extend to the end of the line).
- (void)processedEditing:(NSNotification*)notification
{
	UNUSED(notification);
    	
	NSUInteger mask = self.textView.textStorage.editedMask;
	if ((mask & NSTextStorageEditedCharacters))
	{
		_editCount++;
		setSizeUIntVector(&_lineStarts, 0);

		NSTextStorage* storage = self.textView.textStorage;
		NSRange range = storage.editedRange;
		if (_applier)
		{
			NSUInteger loc = range.location;
			[_applier addDirtyLocation:loc reason:@"user edit"];
		}
		
		// Auto-indent new lines.
		NSString* text = storage.string;
		NSInteger lengthChange = storage.changeInLength;
		NSCharacterSet* ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		if (range.length == 1 && [text characterAtIndex:range.location] == '\n' && lengthChange > 0)
		{
			NSUInteger i = range.location - 1;
			while (i < text.length && [text characterAtIndex:i] != '\n')
				--i;
			
			++i;
			NSUInteger count = 0;
			while (i + count < range.location && [ws characterIsMember:[text characterAtIndex:i+count]])
				++count;
			
			if (count > 0)
			{
				NSString* padding = [text substringWithRange:NSMakeRange(i, count)];
				
				dispatch_queue_t main = dispatch_get_main_queue();
				dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 50*NSEC_PER_MSEC);
				dispatch_after(delay, main, ^{
                    [_textView insertText:padding replacementRange:NSMakeRange(range.location, 0)];
                });
			}
        }
        
        // Update line number button.
        [self _updateLineNumberButton];
        
        // TODO: For rich text documents we dont have a good way to consistently notify plugins
        // about style changes. So, for now, we notify them after the user types (which we have to
        // do anyway because typing changes text attributes).
        if (!_applier)
            [AppDelegate execute:@"apply styles" withSelector:@selector(onAppliedStyles) withObject:self deferBy:0.333];
        
        // TODO: should have a way to notify plugins of edits
		[[NSNotificationCenter defaultCenter] postNotificationName:@"TextWindowEdited" object:self];
	}
}

// This is also called a lot while the user types.
- (void)layoutManager:(NSLayoutManager*)layout didCompleteLayoutForTextContainer:(NSTextContainer*)container atEnd:(BOOL)atEnd
{
	UNUSED(container);
	
	if (!_closed)
	{
		if (_restorer)
		{
			// If there is no language then we can attempt to restore the scroll position
			// immediately. Otherwise we need to wait until styles have begun to be
			// applied (we can't restore scrollers until line heights are correct).
			if (_language == nil || (_applier && _applier.applied))
			{
				// Once some legit styles have been applied we can tell the restorer that
				// styles have been applied. If true is returned then enough styles have
				// been applied that the restorer was able to restore (or it decided that
				// restore wasn't going to work).
				if ([_restorer onCompletedLayout:layout atEnd:atEnd])
					_restorer = nil;
			}
		}
		
		if (atEnd)
		{
			for (LayoutCallback callback in _layoutBlocks)
			{
				callback(self);
			}
			[_layoutBlocks removeAllObjects];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:@"TextWindowFinishedLayout" object:self];
//			DoPruneRanges();
		}
	}
}
- (IBAction)_clickedLineButton:(id)sender
{
    [self jumpToLine:sender];
}

- (void)_updateLineNumberButton
{
    NSString* label = @"";
    
    NSRange range = self.textView.selectedRange;
    NSUInteger firstLine = [self _offsetToLine:range.location];
    
    if (range.length > 0)
    {
        NSUInteger lastLine = [self _offsetToLine:range.location + range.length - 1];
        label = [NSString stringWithFormat:@"%ld-%ld", firstLine, lastLine];
    }
    else
    {
        NSUInteger col = [self _offsetToCol:range.location];
        label = [NSString stringWithFormat:@"%ld:%ld", firstLine, col];
    }
    
    [self.lineButton setTitle:label];
}

- (NSUInteger)_offsetToCol:(NSUInteger)offset
{
    NSUInteger col = 0;

    NSString* text = _textView.textStorage.string;
    while (offset > 0 && offset < text.length)
    {
        unichar ch = [text characterAtIndex:offset - 1];
        if (ch == '\r' || ch == '\n')
            break;
        --offset;
        ++col;
    }
    
    return col + 1;
}

// Note that line numbers are 1-based.
- (NSUInteger)_offsetToLine:(NSUInteger)offset
{
	struct UIntVector* lineStarts = self._getLineStarts;
	
	NSUInteger line = searchUIntVector(lineStarts, offset);
	if (line >= lineStarts->count)
		line = ~line;
	
	if (line == lineStarts->count || lineStarts->data[line] != offset)
		--line;
	
	return line + 1;
	
}

- (NSUInteger)_lineToOffset:(NSUInteger)line
{
	ASSERT(line >= 1);
	
	struct UIntVector* lineStarts = self._getLineStarts;
	if (line-1 < lineStarts->count)
		return lineStarts->data[line - 1];
	else
		return self.text.length - 1;
}

- (struct UIntVector*)_getLineStarts
{
	NSString* text = _textView.textStorage.string;
	if (_lineStarts.count == 0 && text.length > 0)
	{
		pushUIntVector(&_lineStarts, 0);
		for (NSUInteger i = 1; i < text.length; ++i)
		{
			// TextDocument strips out line feeds so this is legit.
			if ([text characterAtIndex:i-1] == '\n')
				pushUIntVector(&_lineStarts, i);
		}
	}
	
	return &_lineStarts;
}

- (bool)_textAt:(NSUInteger)offset matches:(NSString*)str
{
	bool match = false;
	
	NSString* buffer = self.textView.textStorage.string;
	if (offset + str.length <= buffer.length)
	{
		int result = [buffer compare:str options:0 range:NSMakeRange(offset, str.length)];
		match = result == NSOrderedSame;
	}
	
	return match;
}

- (TextStyles*)_createTextStyles
{
	NSString* dir = [Paths installedDir:@"styles"];
	NSString* path = [dir stringByAppendingPathComponent:self._getDefaultStyleName];
	return [[TextStyles alloc] initWithPath:path expectBackColor:true];
}

- (TextStyles*)_createDefaultTextStyles
{
	NSString* dir = [Paths installedDir:@"settings"];
	NSString* path = [dir stringByAppendingPathComponent:@"default-text.rtf"];
	return [[TextStyles alloc] initWithPath:path expectBackColor:true];
}


- (void)_mainChanged:(NSNotification*)notification
{
    // Couple points:
    // 1) We don't use NSApp orderedWindows because it was a major bottleneck.
    // 2) We don't reset _frontmost because we want the frontmost text document,
    // not the main window.
    NSWindow* window = notification.object;
    if (window.windowController)
        if ([window.windowController isKindOfClass:[TextController class]])
            _frontmost = window.windowController;
}

@end
