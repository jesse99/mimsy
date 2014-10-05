#import "TextController.h"

#import "AppDelegate.h"
#import "ApplyStyles.h"
#import "AppSettings.h"
#import "Balance.h"
#import "ColorCategory.h"
#import "ConfigParser.h"
#import "FunctionalTest.h"
#import "Language.h"
#import "Languages.h"
#import "Paths.h"
#import "ProcFileSystem.h"
#import "ProcFiles.h"
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

@implementation TextController
{
	ProcFileReader* _pathFile;
	ProcFileReadWrite* _colNumFile;
	ProcFileReader* _elementNameFile;
	ProcFileReader* _elementNamesFile;
	ProcFileReader* _languageFile;
	ProcFileReadWrite* _lineNumFile;
	ProcFileReadWrite* _selectionRangeFileW;
	ProcFileReadWrite* _selectionTextFile;
	ProcFileReadWrite* _textFile;
	ProcFileReader* _titleFile;
	ProcFileReadWrite* _wordWrapFile;
	ProcFileKeyStore* _keyStoreFile;

	ProcFileReadWrite* _addTempBackColorFile;
	ProcFileReadWrite* _removeTempBackColorFile;
	ProcFileReadWrite* _addTempForeColorFile;
	ProcFileReadWrite* _removeTempForeColorFile;
	ProcFileReadWrite* _addTempUnderlineFile;
	ProcFileReadWrite* _removeTempUnderlineFile;
	ProcFileReadWrite* _addTempStrikeThroughFile;
	ProcFileReadWrite* _removeTempStrikeThroughFile;

	RestoreView* _restorer;
	bool _closed;
	bool _wordWrap;
	NSUInteger _editCount;
	Language* _language;
	TextStyles* _styles;
	ApplyStyles* _applier;
	NSMutableArray* _layoutBlocks;
	struct UIntVector _lineStarts;	// first index is at zero, other indexes are one past new-lines
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
		
 		updateInstanceCount(@"TextController", +1);
		updateInstanceCount(@"TextWindow", +1);

		AppDelegate* app = [NSApp delegate];
		ProcFileSystem* fs = app.procFileSystem;
		if (fs)
		{
			_colNumFile = [[ProcFileReadWrite alloc]
				initWithDir:^NSString *{return [self getProcFilePath];}
				fileName:@"column-number"
				readStr:^NSString *
				{
				   NSRange range = self.textView.selectedRange;
				   NSUInteger loc = range.location;
				   while (loc > 0 && [self.text characterAtIndex:loc-1] != '\n')
					   --loc;
				   return [NSString stringWithFormat:@"%lu", range.location - loc + 1];
				}
				writeStr:^(NSString* text)
				{
					// Find the start of the line.
					NSUInteger loc = self.textView.selectedRange.location;
					while (loc > 0 && [self.text characterAtIndex:loc-1] != '\n')
						--loc;
					
					// Jump to the column, but don't go past the end of the line.
					NSInteger col = [text integerValue];
					while (loc < self.text.length && [self.text characterAtIndex:loc] != '\n' && col > 1)
					{
						--col;
						++loc;
					}
					
					NSRange range = NSMakeRange(loc, 0);
					[self.textView setSelectedRange:range];

					range = NSMakeRange(loc, 1);
					[self.textView scrollRangeToVisible:range];
					[self.textView showFindIndicatorForRange:range];
				}];
			_elementNameFile = [[ProcFileReader alloc]
								initWithDir:^NSString *{return [self getProcFilePath];}
								fileName:@"element-name"
								readStr:^NSString *{return [self getElementNameFor:self.textView.selectedRange];}];
			_elementNamesFile = [[ProcFileReader alloc]
								initWithDir:^NSString *{return [self getProcFilePath];}
								fileName:@"element-names"
								readStr:^NSString *{return [self getElementNames];}];
			_languageFile = [[ProcFileReader alloc]
								initWithDir:^NSString *{return [self getProcFilePath];}
								fileName:@"language"
							 readStr:^NSString *{return self.language ? self.language.name : @"";}];
			_lineNumFile = [[ProcFileReadWrite alloc]
				initWithDir:^NSString *{return [self getProcFilePath];}
				fileName:@"line-number"
				readStr:^NSString *
				{
					int line = 1;
					NSString* text = self.text;
					NSUInteger loc = self.textView.selectedRange.location;
					for (NSUInteger i = 0; i < text.length && i < loc; i++)
					{
						if ([text characterAtIndex:i] == '\n')
							++line;
					}
					return [NSString stringWithFormat:@"%d", line];
				}
				writeStr:^(NSString* text)
				{
					NSUInteger i = 0;
					NSInteger currentLine = 1;
					NSInteger targetLine = [text integerValue];
					while (i < self.text.length && currentLine < targetLine)
					{
						if ([self.text characterAtIndex:i] == '\n')
							++currentLine;
						++i;
					}
					
					NSUInteger j = i;
					while (j < self.text.length && [self.text characterAtIndex:j] != '\n')
					{
						++j;
					}
					
					NSRange range = NSMakeRange(i, 0);
					[self.textView setSelectedRange:range];

					range = NSMakeRange(i, j-i+1);
					[self.textView scrollRangeToVisible:range];
					[self.textView showFindIndicatorForRange:range];
				}];
			_pathFile = [[ProcFileReader alloc]
						 initWithDir:^NSString *{return [self getProcFilePath];}
						 fileName:@"path"
						 readStr:^NSString *{return [self path];}];
			_selectionRangeFileW = [[ProcFileReadWrite alloc]
				initWithDir:^NSString *{return [self getProcFilePath];}
				fileName:@"selection-range"
				readStr:^NSString *{
					NSRange range = self.textView.selectedRange;
					return [NSString stringWithFormat:@"%lu\f%lu", (unsigned long)range.location, (unsigned long)range.length];
				}
				writeStr:^(NSString* text)
				{
					NSArray* parts = [text componentsSeparatedByString:@"\f"];
					if (parts.count == 2)
					{
						NSInteger loc = [parts[0] integerValue];
						NSInteger len = [parts[1] integerValue];
						if (loc + len > self.text.length)
							len = (NSInteger) self.text.length - loc;
						
						NSRange range = NSMakeRange((NSUInteger)loc, (NSUInteger)len);
						dispatch_queue_t main = dispatch_get_main_queue();
						dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
						dispatch_after(delay, main, ^{
							// We need to defer this in order for scrollRangeToVisible to work
							// reliably (e.g. for option-tab).
							[self.textView setSelectedRange:range];
							[self.textView scrollRangeToVisible:range];
							[self.textView showFindIndicatorForRange:range];
						});
					}
				}];
			_selectionTextFile = [[ProcFileReadWrite alloc]
								  initWithDir:^NSString *{return [self getProcFilePath];}
								  fileName:@"selection-text"
								  readStr:^NSString *{
									  NSRange range = self.textView.selectedRange;
									  return [self.text substringWithRange:range];
								  }
								  writeStr:^(NSString* text)
								  {
									  NSRange range = self.textView.selectedRange;
									  if ([self.textView shouldChangeTextInRange:range replacementString:text])
									  {
										  [self.textView replaceCharactersInRange:range withString:text];
										  if (text.length > 0)
											  [self.textView.undoManager setActionName:@"Replace Text"];
										  else
											  [self.textView.undoManager setActionName:@"Delete Text"];
										  [self.textView didChangeText];
									  }
								  }];
			_textFile = [[ProcFileReadWrite alloc]
				initWithDir:^NSString *{return [self getProcFilePath];}
				fileName:@"text"
				readStr:^NSString *{
					return self.text;
				}
				writeStr:^(NSString* text)
				{
					NSRange range = NSMakeRange(0, self.text.length);
					if ([self.textView shouldChangeTextInRange:range replacementString:text])
					{
						[self.textView replaceCharactersInRange:range withString:text];
						if (text.length > 0)
							[self.textView.undoManager setActionName:@"Replace Text"];
						else
							[self.textView.undoManager setActionName:@"Delete Text"];
						[self.textView didChangeText];
					}
				}];
			_titleFile = [[ProcFileReader alloc]
						initWithDir:^NSString *{return [self getProcFilePath];}
						fileName:@"title"
						readStr:^NSString *{return self.window.title;}];
			_wordWrapFile = [[ProcFileReadWrite alloc]
			   initWithDir:^NSString *{return [self getProcFilePath];}
			   fileName:@"word-wrap"
			   readStr:^NSString *{
				   return _wordWrap ? @"true" : @"false";
			   }
			   writeStr:^(NSString* text)
			   {
				   bool wrap = [text isEqualToString:@"true"];
				   if (wrap != _wordWrap)
				   {
					   _wordWrap = wrap;
					   [self doResetWordWrap];
				   }
			   }];
			_keyStoreFile = [[ProcFileKeyStore alloc] initWithDir:^NSString*
				{
					return [[self getProcFilePath] stringByAppendingPathComponent:@"key-values"];
				}];
			
			_addTempBackColorFile = [[ProcFileReadWrite alloc]
									 initWithDir:^NSString *{return [self getProcFilePath];}
									 fileName:@"add-temp-back-color"
									 readStr:^NSString *{
										 return @"";
									 }
									 writeStr:^(NSString* text)
									 {
										 NSArray* parts = [text componentsSeparatedByString:@"\f"];
										 if (parts.count == 3)
										 {
											 NSInteger loc = [parts[0] integerValue];
											 NSInteger len = [parts[1] integerValue];
											 NSString* name = parts[2];
											 NSColor* color = [NSColor colorWithMimsyName:name];
											 if (loc + len > self.text.length)
												 len = (NSInteger) self.text.length - loc;
											 
											 NSArray* managers = self.textView.textStorage.layoutManagers;
											 NSLayoutManager* layout = managers[0];
											 [layout addTemporaryAttribute:NSBackgroundColorAttributeName value:color forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
										 }
									 }];
			_addTempForeColorFile = [[ProcFileReadWrite alloc]
									 initWithDir:^NSString *{return [self getProcFilePath];}
									 fileName:@"add-temp-fore-color"
									 readStr:^NSString *{
										 return @"";
									 }
									 writeStr:^(NSString* text)
									 {
										 NSArray* parts = [text componentsSeparatedByString:@"\f"];
										 if (parts.count == 3)
										 {
											 NSInteger loc = [parts[0] integerValue];
											 NSInteger len = [parts[1] integerValue];
											 NSString* name = parts[2];
											 NSColor* color = [NSColor colorWithMimsyName:name];
											 if (loc + len > self.text.length)
												 len = (NSInteger) self.text.length - loc;
											 
											 NSArray* managers = self.textView.textStorage.layoutManagers;
											 NSLayoutManager* layout = managers[0];
											 [layout addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
										 }
									 }];
			_addTempUnderlineFile = [[ProcFileReadWrite alloc]
									 initWithDir:^NSString *{return [self getProcFilePath];}
									 fileName:@"add-temp-underline"
									 readStr:^NSString *{
										 return @"";
									 }
									 writeStr:^(NSString* text)
									 {
										 NSArray* parts = [text componentsSeparatedByString:@"\f"];
										 if (parts.count == 4)
										 {
											 NSInteger loc = [parts[0] integerValue];
											 NSInteger len = [parts[1] integerValue];
											 NSInteger mask = [parts[2] integerValue];
											 NSString* name = parts[3];
											 NSColor* color = [NSColor colorWithMimsyName:name];
											 if (loc + len > self.text.length)
												 len = (NSInteger) self.text.length - loc;
											 
											 NSArray* managers = self.textView.textStorage.layoutManagers;
											 NSLayoutManager* layout = managers[0];
											 [layout addTemporaryAttribute:NSUnderlineStyleAttributeName value:@(mask) forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
											 [layout addTemporaryAttribute:NSUnderlineColorAttributeName value:color forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
										 }
									 }];
			_addTempStrikeThroughFile = [[ProcFileReadWrite alloc]
				 initWithDir:^NSString *{return [self getProcFilePath];}
				 fileName:@"add-temp-strike-through"
				 readStr:^NSString *{
					 return @"";
				 }
				 writeStr:^(NSString* text)
				 {
					 NSArray* parts = [text componentsSeparatedByString:@"\f"];
					 if (parts.count == 4)
					 {
						 NSInteger loc = [parts[0] integerValue];
						 NSInteger len = [parts[1] integerValue];
						 NSInteger mask = [parts[2] integerValue];
						 NSString* name = parts[3];
						 NSColor* color = [NSColor colorWithMimsyName:name];
						 if (loc + len > self.text.length)
							 len = (NSInteger) self.text.length - loc;
						 
						 NSArray* managers = self.textView.textStorage.layoutManagers;
						 NSLayoutManager* layout = managers[0];
						 [layout addTemporaryAttribute:NSStrikethroughStyleAttributeName value:@(mask) forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
						 [layout addTemporaryAttribute:NSStrikethroughColorAttributeName value:color forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
					 }
				 }];
			_removeTempBackColorFile = [[ProcFileReadWrite alloc]
										initWithDir:^NSString *{return [self getProcFilePath];}
										fileName:@"remove-temp-back-color"
										readStr:^NSString *{
											return @"";
										}
										writeStr:^(NSString* text)
										{
											NSArray* parts = [text componentsSeparatedByString:@"\f"];
											if (parts.count == 2)
											{
												NSInteger loc = [parts[0] integerValue];
												NSInteger len = [parts[1] integerValue];
												if (loc + len > self.text.length)
													len = (NSInteger) self.text.length - loc;
												
												NSArray* managers = self.textView.textStorage.layoutManagers;
												NSLayoutManager* layout = managers[0];
												[layout removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
											}
										}];
			_removeTempForeColorFile = [[ProcFileReadWrite alloc]
										initWithDir:^NSString *{return [self getProcFilePath];}
										fileName:@"remove-temp-fore-color"
										readStr:^NSString *{
											return @"";
										}
										writeStr:^(NSString* text)
										{
											NSArray* parts = [text componentsSeparatedByString:@"\f"];
											if (parts.count == 2)
											{
												NSInteger loc = [parts[0] integerValue];
												NSInteger len = [parts[1] integerValue];
												if (loc + len > self.text.length)
													len = (NSInteger) self.text.length - loc;
												
												NSArray* managers = self.textView.textStorage.layoutManagers;
												NSLayoutManager* layout = managers[0];
												[layout removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
											}
										}];
			_removeTempUnderlineFile = [[ProcFileReadWrite alloc]
										initWithDir:^NSString *{return [self getProcFilePath];}
										fileName:@"remove-temp-underline"
										readStr:^NSString *{
											return @"";
										}
										writeStr:^(NSString* text)
										{
											NSArray* parts = [text componentsSeparatedByString:@"\f"];
											if (parts.count == 2)
											{
												NSInteger loc = [parts[0] integerValue];
												NSInteger len = [parts[1] integerValue];
												if (loc + len > self.text.length)
													len = (NSInteger) self.text.length - loc;
												
												NSArray* managers = self.textView.textStorage.layoutManagers;
												NSLayoutManager* layout = managers[0];
												[layout removeTemporaryAttribute:NSUnderlineStyleAttributeName forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
												[layout removeTemporaryAttribute:NSUnderlineColorAttributeName forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
											}
										}];
			_removeTempStrikeThroughFile = [[ProcFileReadWrite alloc]
				initWithDir:^NSString *{return [self getProcFilePath];}
				fileName:@"remove-temp-strike-through"
				readStr:^NSString *{
					return @"";
				}
				writeStr:^(NSString* text)
				{
					NSArray* parts = [text componentsSeparatedByString:@"\f"];
					if (parts.count == 2)
					{
						NSInteger loc = [parts[0] integerValue];
						NSInteger len = [parts[1] integerValue];
						if (loc + len > self.text.length)
							len = (NSInteger) self.text.length - loc;
										  
						NSArray* managers = self.textView.textStorage.layoutManagers;
						NSLayoutManager* layout = managers[0];
						[layout removeTemporaryAttribute:NSStrikethroughStyleAttributeName forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
						[layout removeTemporaryAttribute:NSStrikethroughColorAttributeName forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
					}
				}];
			
			[fs addReader:_elementNameFile];
			[fs addReader:_elementNamesFile];
			[fs addReader:_languageFile];
			[fs addReader:_pathFile];
			[fs addReader:_titleFile];

			[fs addWriter:_colNumFile];
			[fs addWriter:_lineNumFile];
			[fs addWriter:_selectionRangeFileW];
			[fs addWriter:_selectionTextFile];
			[fs addWriter:_textFile];
			[fs addWriter:_wordWrapFile];
			[fs addWriter:_keyStoreFile];

			[fs addWriter:_addTempBackColorFile];
			[fs addWriter:_removeTempBackColorFile];
			[fs addWriter:_addTempForeColorFile];
			[fs addWriter:_removeTempForeColorFile];
			[fs addWriter:_addTempUnderlineFile];
			[fs addWriter:_removeTempUnderlineFile];
			[fs addWriter:_addTempStrikeThroughFile];
			[fs addWriter:_removeTempStrikeThroughFile];
		}
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languagesChanged:) name:@"LanguagesChanged" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stylesChanged:) name:@"StylesChanged" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
	}
    
	return self;
}

- (NSString*)getProcFilePath
{
	__block NSString* path = nil;
	
	__block int index = 1;
	[TextController enumerate:^(TextController *controller, bool* stop) {
		if (controller == self)
		{
			path = [NSString stringWithFormat:@"/text-window/%d", index];
			*stop = true;
		}
		++index;
	}];
	
	return path;
}

- (void)dealloc
{
	updateInstanceCount(@"TextController", -1);
	freeUIntVector(&_lineStarts);
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

	if (!_language)
	{
		NSDocument* doc = self.document;
		if ([doc.fileType contains:@"Plain Text"])
			[self.textView setBackgroundColor:_styles.backColor];
	}
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

- (NSString*)getElementNames
{
	__block NSInteger currentIndex = -1;
	__block struct RangeVector ranges = newRangeVector();
	__block NSMutableArray* names = [NSMutableArray new];
	
	if (_language)
	{
		NSAttributedString* str = self.textView.textStorage;
		NSRange currentRange = self.textView.selectedRange;
		[str enumerateAttribute:@"element name" inRange:NSMakeRange(0, str.length) options:0 usingBlock:^(NSString* value, NSRange range, BOOL *stop) {
			UNUSED(stop);
			[names addObject:value];
			pushRangeVector(&ranges, range);
			
			if (currentIndex < 0 && currentRange.location >= range.location && currentRange.location+currentRange.length <= range.location+range.length)
				currentIndex = (int) names.count - 1;
		}];
	}
	
	NSMutableString* text = [NSMutableString stringWithCapacity:names.count*(6+1 + 3+1 + 2+1)];
	[text appendFormat:@"%ld\n", (long)currentIndex];
	
	for (NSUInteger i = 0; i < names.count; ++i)
	{
		[text appendFormat:@"%@\f%lu\f%lu\n", names[i], (unsigned long)ranges.data[i].location, (unsigned long)ranges.data[i].length];
	}
	
	freeRangeVector(&ranges);
	
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
	NSRange range = self.textView.selectedRange;
	NSDictionary* attrs = [_styles attributesForElement:@"normal"];
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
	for (NSWindow* window in [NSApp orderedWindows])
	{
		if (window.isVisible || window.isMiniaturized)
			if (window.windowController)
				if ([window.windowController isKindOfClass:[TextController class]])
					return window.windowController;
	}
	
	return nil;
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
		LOG("Text:Verbose", "Set language for %s to %s", STR([self.path lastPathComponent]), STR(lang));
		
		if (_language)
			_styles = [self _createTextStyles];
		else
			_styles = [self _createDefaultTextStyles];

		if (_language && !_applier)
			_applier = [[ApplyStyles alloc] init:self];
		else if (!_language && _applier)
			_applier = nil;
		
		[self resetAttributes];
		if (_applier)
			[_applier addDirtyLocation:0 reason:@"set language"];
		
		NSDictionary* attrs = [_styles attributesForElement:@"normal"];
		[self.textView setTypingAttributes:attrs];
		[self _resetAutomaticSubstitutions];
	}
}

- (void)_resetAutomaticSubstitutions
{
	NSDocument* doc = self.document;
	NSString* type = doc.fileType;
	bool enable = _language == nil && ![type contains:@"Plain Text"] && [AppSettings boolValue:@"EnableSubstitutions" missing:true];
	[self.textView setAutomaticQuoteSubstitutionEnabled:enable];
	[self.textView setAutomaticDashSubstitutionEnabled:enable];
	[self.textView setAutomaticTextReplacementEnabled:enable];
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
	
	if (_language)
	{
		_styles = [[TextStyles alloc] initWithPath:_styles.path expectBackColor:true];
		if (_applier)
			[_applier resetStyles];
	}
}

- (void)settingsChanged:(NSNotification*)notification
{
	UNUSED(notification);
	
	[self _resetAutomaticSubstitutions];
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

	NSDictionary* attrs = [_styles attributesForElement:@"normal"];
	[self.textView setTypingAttributes:attrs];
	if (!_language)
	{
		NSDocument* doc = self.document;
		if ([doc.fileType contains:@"Plain Text"])
			[self.textView.textStorage setAttributes:attrs range:NSMakeRange(0, self.textView.textStorage.length)];
	}

	[self _resetAutomaticSubstitutions];
}

// Should be called after anything that might change attributes.
- (void)resetAttributes
{
	// if we don't have a language we'll leave whatever the user is
	// using alone (i.e. we only set styles for a document without
	// a language when we first open it).
	if (_language)
		[self.textView setTypingAttributes:[_styles attributesForElement:@"normal"]];
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
	
	[_wordWrapFile notifyIfChanged];
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
	
	[_colNumFile notifyIfChanged];
	[_lineNumFile notifyIfChanged];
	[_selectionRangeFileW notifyIfChanged];
	[_selectionTextFile notifyIfChanged];

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
				dispatch_after(delay, main, ^{[_textView insertText:padding];});
			}
		}

		[_selectionTextFile notifyIfChanged];
		[_textFile notifyIfChanged];			// TODO: watching this can be expensive for large files, could maybe use a custom proc file class
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

@end
