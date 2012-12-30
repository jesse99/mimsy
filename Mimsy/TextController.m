#import "TextController.h"

#import "Language.h"
#import "Languages.h"
#import "RestoreView.h"
#import "TextDocument.h"
#import "WindowsDatabase.h"

@implementation TextController
{
	RestoreView* _restorer;
	bool _closed;
	bool _wordWrap;
	NSUInteger _editCount;
	Language* _language;
}

- (id)init
{
    self = [super initWithWindowNibName:@"TextDocument"];
    if (self)
	{
		[self setShouldCascadeWindows:NO];

		// This will be set to nil once the view has been restored.
		_restorer = [[RestoreView alloc] init:self];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[[self document] controllerDidLoad];

	__weak id this = self;
	[self.textView.textStorage setDelegate:this];
	[self.textView.layoutManager setDelegate:this];
	[self.textView.layoutManager setBackgroundLayoutEnabled:YES];
}

- (void)windowWillClose:(NSNotification*)notification
{
	(void) notification;
	
	_closed = true;

	NSString* path = [self path];
	if (path)
	{
		// If the document has changes but is not being saved then we don't
		// want to persist this information because it will likely be wrong when
		// the old text is loaded.
		if (![self.document isDocumentEdited])
		{
			struct WindowInfo info;
			info.length    = (NSInteger) self.text.length;
			info.origin    = self.scrollView.contentView.bounds.origin;
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

- (void)open
{
	// TODO: need to do this stuff
	//Broadcaster.Invoke("opening document window", m_boss);
	
	[self.window makeKeyAndOrderFront:self];
	
	//Broadcaster.Invoke("opened document window", m_boss);
	//synchronizeWindowTitleWithDocumentName();		// bit of a hack, but we need something like this for IDocumentWindowTitle to work
	
	//DoSetTabSettings();
}

- (NSAttributedString*)attributedText
{
	return self.textView.textStorage;
}

- (void)setAttributedText:(NSAttributedString*)text
{
	_editCount++;
	[self.textView.textStorage setAttributedString:text];
}

- (NSString*)text
{
	return [[self.textView textStorage] string];
}

- (void)setLanguage:(Language*)lang
{
	if (lang != _language)
	{
		_language = lang;
	}
}

- (NSString*)path
{
	NSURL* url = [self.document fileURL];
	return [url path];
}

- (void)onPathChanged
{
	NSString* path = [self path];
	if (path)
	{
		NSRect frame = [WindowsDatabase getFrame:path];
		if (NSWidth(frame) >= 40)
			[self.window setFrame:frame display:YES];	// note that Cocoa will ensure that windows with title bars are not moved off screen
		
		NSString* name = [path lastPathComponent];
		self.Language = [Languages findWithFileName:name contents:self.text];
		
		if (_restorer)
			[_restorer setPath:path];
	}
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
		NSSize contentSize = _scrollView.contentView.bounds.size;
		[_textView.textContainer setContainerSize:NSMakeSize(contentSize.width, HUGE_VAL)];
		[_textView.textContainer setWidthTracksTextView:YES];
	}
	else
	{
		[_textView.textContainer setContainerSize:NSMakeSize(HUGE_VAL, HUGE_VAL)];
		[_textView.textContainer setWidthTracksTextView:NO];
	}
	
	[_textView sizeToFit];
}

// Note that this is called for every key stroke.
- (void)textStorageDidProcessEditing:(NSNotification*)notification
{
	(void)notification;
	
	NSUInteger mask = self.textView.textStorage.editedMask;
	if ((mask & NSTextStorageEditedCharacters))
	{
		_editCount++;
	}
}

- (void)layoutManager:(NSLayoutManager*)layout didCompleteLayoutForTextContainer:(NSTextContainer*)container atEnd:(BOOL)atEnd
{
	(void) container;
	
	if (!_closed)
	{
		if (_restorer)
			//if (_restorer && (m_applier.Applied || m_language == null))
			if ([_restorer onCompletedLayout:layout atEnd:atEnd])
				_restorer = nil;
		
//		if (atEnd)
//		{
//			Broadcaster.Invoke("layout completed", m_boss);
//			DoPruneRanges();
//		}
	}
}

@end
