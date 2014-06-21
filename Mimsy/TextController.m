#import "TextController.h"

#import "ApplyStyles.h"
#import "Assert.h"
#import "Balance.h"
#import "ConfigParser.h"
#import "FunctionalTest.h"
#import "Language.h"
#import "Languages.h"
#import "Logger.h"
#import "Paths.h"
#import "RestoreView.h"
#import "StartupScripts.h"
#import "TextView.h"
#import "TextDocument.h"
#import "TextStyles.h"
#import "TimeMachine.h"
#import "TranscriptController.h"
#import "WarningWindow.h"
#import "WindowsDatabase.h"

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
}

- (id)init
{
    self = [super initWithWindowNibName:@"TextDocument"];
    if (self)
	{
		[self setShouldCascadeWindows:NO];

		// This will be set to nil once the view has been restored.
		_restorer = [[RestoreView alloc] init:self];
		
		_layoutBlocks = [NSMutableArray new];
		
 		updateInstanceCount(@"TextController", +1);
		updateInstanceCount(@"TextWindow", +1);

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languagesChanged:) name:@"LanguagesChanged" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stylesChanged:) name:@"StylesChanged" object:nil];
	}
    
	return self;
}

- (void)dealloc
{
	updateInstanceCount(@"TextController", -1);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[self.document controllerDidLoad];
	[self.textView onOpened:self];

	__weak id this = self;
	[self.textView setDelegate:this];
	[self.textView.textStorage setDelegate:this];
	[self.textView.layoutManager setDelegate:this];
	[self.textView.layoutManager setBackgroundLayoutEnabled:YES];

	if (self.path)
		[self.textView setTypingAttributes:TextStyles.fallbackStyle];
	else
		[self _setDefaultUntitledStyles];
}

- (void)registerBlockWhenLayoutCompletes:(LayoutCallback)block
{
	[_layoutBlocks addObject:block];
}

- (void)windowWillClose:(NSNotification*)notification
{
	UNUSED(notification);
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TextWindowClosing" object:self];
	
	_closed = true;
	updateInstanceCount(@"TextWindow", -1);

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
		
//		if (Path.Contains("/var/") && Path.Contains("/-Tmp-/"))		// TODO: seems kind of fragile
//			DoDeleteFile(Path);
	}
	
//	var complete = m_boss.Get<IAutoComplete>();
//	complete.Close();
//	
//	if (m_watcher != null)
//	{
//		m_watcher.Dispose();
//		m_watcher.Changed -= this.DoDirChanged;
//		m_watcher = null;
//	}
//	
//	Broadcaster.Unregister(this);
//	
//	if (m_applier != null)
//	{
//		m_applier.Stop();
//	}
//	((DeclarationsPopup) m_decPopup.Value).Stop();
//	
//	m_textView.Value.Call("onClosing:", this);
	
	// If the windows are closed very very quickly and we don't do this
	// we get a crash when Cocoa tries to call our delegate.
	[self.textView.layoutManager setDelegate:nil];
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
		LOG_INFO("Text", "Window for %s opened", STR([self.path lastPathComponent]));
	else
		LOG_INFO("Text", "Untitled window opened");
		
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
	if ([self respondsToSelector:sel])
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
	
	NSRange range = self.textView.selectedRange;
	if (range.length > 0)
	{
		if ([self.textView shouldChangeTextInRange:range replacementString:nil])
		{
			NSTextStorage* storage = self.textView.textStorage;
			[storage setAttributes:[TextStyles fallbackStyle] range:range];
			[self.textView didChangeText];
		}
	}
	else
	{
		[self.textView setTypingAttributes:[TextStyles fallbackStyle]];
	}
}

+ (TextController*)frontmost
{
	for (NSWindow* window in [NSApp orderedWindows])
	{
		if (window.isVisible || window.isMiniaturized)
			if (window.windowController)
				if ([window.windowController isKindOfClass:[TextController class]])
					return window.windowController;
	}
	
	return nil;
}

+ (void)enumerate:(void (^)(TextController*))block
{
	for (NSWindow* window in [NSApp orderedWindows])
	{
		if (window.isVisible || window.isMiniaturized)
			if (window.windowController)
				if ([window.windowController isKindOfClass:[TextController class]])
					block(window.windowController);
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
		addFunctionalTestHelpContext(result, path);
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
	[self resetAttributes];
	if (_applier)
		[_applier addDirtyLocation:0 reason:@"set text"];
}

// TODO: scripts can call this quite a bit: might be nice to cache the value until an edit happens
- (NSString*)text
{
	return [[self.textView textStorage] string];
}

- (Language*)language
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
		LOG_INFO("Text", "Set language for %s to %s", STR([self.path lastPathComponent]), STR(lang));
		
		if (_language && !_styles)
		{
			_styles = [self _createTextStyles];
		}
		else if (!_language && _styles)
		{
			_styles = nil;
		}
		
		if (_language && !_applier)
			_applier = [[ApplyStyles alloc] init:self];
		else if (!_language && _applier)
			_applier = nil;
		
		[self resetAttributes];
		if (_applier)
			[_applier addDirtyLocation:0 reason:@"set language"];
	}
}

- (void)languagesChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
	if (_language)
		[self setLanguage:[Languages findWithlangName:_language.name]];
}

- (void)stylesChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
	if (_styles)
	{
		_styles = [[TextStyles alloc] initWithPath:_styles.path expectBackColor:true];
		if (_applier)
			[_applier resetStyles];
	}
}

- (void)changeStyle:(NSString*)path
{
	assert(_language);
	_styles = [[TextStyles alloc] initWithPath:path expectBackColor:true];
	if (_applier)
		[_applier resetStyles];
}

- (NSString*)path
{
	NSURL* url = [self.document fileURL];
	return [url path];
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
	if (path)
	{
		[self _positionWindow:path];
		
		NSString* name = [path lastPathComponent];
		self.Language = [Languages findWithFileName:name contents:self.text];
		
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
}

// Should be called after anything that might change attributes.
- (void)resetAttributes
{
	if (_language)
	{
		[self.textView setTypingAttributes:[_styles attributesForElement:@"normal"]];
	}
	else
	{
		[self.textView setTypingAttributes:TextStyles.fallbackStyle];
	}
}

- (void)showLine:(NSInteger)line atCol:(NSInteger)col withTabWidth:(NSInteger)width
{
	UNUSED(line, col, width);
	
	// TODO: this is Editor.ShowLine which calls TextController.ShowLine
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

	[StartupScripts invokeTextSelectionChanged:self.document slocation:range.location slength:range.length];
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
- (void)textStorageDidProcessEditing:(NSNotification*)notification
{
	UNUSED(notification);
	
	NSUInteger mask = self.textView.textStorage.editedMask;
	if ((mask & NSTextStorageEditedCharacters))
	{
		_editCount++;

		NSTextStorage* storage = self.textView.textStorage;
		NSRange range = storage.editedRange;
		if (_applier)
		{
			NSUInteger loc = range.location;
			[_applier addDirtyLocation:loc reason:@"user edit"];
		}
		
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

- (void)_setDefaultUntitledStyles
{
	TextStyles* styles = [self _createTextStyles];
	[self.textView setBackgroundColor:styles.backColor];
	[self.textView setTypingAttributes:[styles attributesForElement:@"Normal"]];
}

- (TextStyles*)_createTextStyles
{
	NSString* dir = [Paths installedDir:@"styles"];
	NSString* path = [dir stringByAppendingPathComponent:self._getDefaultStyleName];
	return [[TextStyles alloc] initWithPath:path expectBackColor:true];
}

@end
