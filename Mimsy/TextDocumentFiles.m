#import "TextDocumentFiles.h"

#import "AppDelegate.h"
#import "ColorCategory.h"
#import "Extensions.h"
#import "Language.h"
#import "ProcFiles.h"
#import "ProcFileSystem.h"
#import "TextController.h"
#import "TextView.h"

@implementation TextDocumentFiles
{
	__weak TextController* _frontmost;

	ProcFileReadWrite* _addTempBackColorFile;
	ProcFileReadWrite* _addTempForeColorFile;
	ProcFileReadWrite* _addTempStrikeThroughFile;
    ProcFileReadWrite* _addTempUnderlineFile;
	ProcFileReadWrite* _colNumFile;
	ProcFileReader* _elementNameFile;
	ProcFileReader* _elementNamesFile;
	ProcFileKeyStoreRW* _keyStoreFile;
	ProcFileReader* _languageFile;
    ProcFileReader* _lengthFile;
	ProcFileReadWrite* _lineNumFile;
	ProcFileReader* _lineSelectionFile;
	ProcFileReader* _pathFile;
	ProcFileReadWrite* _removeTempBackColorFile;
	ProcFileReadWrite* _removeTempForeColorFile;
	ProcFileReadWrite* _removeTempStrikeThroughFile;
	ProcFileReadWrite* _removeTempUnderlineFile;
	ProcFileReadWrite* _selectionRangeFile;
	ProcFileReadWrite* _selectionTextFile;
	ProcFileReadWrite* _textFile;
	ProcFileReader* _titleFile;
	ProcFileReadWrite* _wordWrapFile;
}

- (id)init
{
	self = [super init];
	if (self)
	{
		_addTempBackColorFile = [self _createReadWriter:@"add-temp-back-color"
			readBlock:^NSString* (TextController* controller)
			 {
				 UNUSED(controller);
				 return @"";
			 }
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSArray* parts = [text componentsSeparatedByString:@"\f"];
				if (parts.count == 3)
				{
					NSInteger loc = [parts[0] integerValue];
					NSInteger len = [parts[1] integerValue];
					NSString* name = parts[2];
					NSColor* color = [NSColor colorWithMimsyName:name];
					if (loc + len > controller.text.length)
						len = (NSInteger) controller.text.length - loc;

					NSArray* managers = controller.textView.textStorage.layoutManagers;
					NSLayoutManager* layout = managers[0];
					[layout addTemporaryAttribute:NSBackgroundColorAttributeName value:color forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
				}
			}];
		
		_addTempForeColorFile = [self _createReadWriter:@"add-temp-fore-color"
			readBlock:^NSString* (TextController* controller)
			{
				UNUSED(controller);
				return @"";
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSArray* parts = [text componentsSeparatedByString:@"\f"];
				if (parts.count == 3)
				{
					NSInteger loc = [parts[0] integerValue];
					NSInteger len = [parts[1] integerValue];
					NSString* name = parts[2];
					NSColor* color = [NSColor colorWithMimsyName:name];
					if (loc + len > controller.text.length)
						len = (NSInteger) controller.text.length - loc;
					
					NSArray* managers = controller.textView.textStorage.layoutManagers;
					NSLayoutManager* layout = managers[0];
					[layout addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
				}
			}];
		
		_addTempStrikeThroughFile = [self _createReadWriter:@"add-temp-strike-through"
			readBlock:^NSString* (TextController* controller)
			{
				UNUSED(controller);
				return @"";
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSArray* parts = [text componentsSeparatedByString:@"\f"];
				if (parts.count == 4)
				{
					NSInteger loc = [parts[0] integerValue];
					NSInteger len = [parts[1] integerValue];
					NSInteger mask = [parts[2] integerValue];
					NSString* name = parts[3];
					NSColor* color = [NSColor colorWithMimsyName:name];
					if (loc + len > controller.text.length)
						len = (NSInteger) controller.text.length - loc;
					
					NSArray* managers = controller.textView.textStorage.layoutManagers;
					NSLayoutManager* layout = managers[0];
					[layout addTemporaryAttribute:NSStrikethroughStyleAttributeName value:@(mask) forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
					[layout addTemporaryAttribute:NSStrikethroughColorAttributeName value:color forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
				}
			}];
		
		_addTempUnderlineFile = [self _createReadWriter:@"add-temp-underline"
			readBlock:^NSString* (TextController* controller)
			{
				UNUSED(controller);
				return @"";
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSArray* parts = [text componentsSeparatedByString:@"\f"];
				if (parts.count == 4)
				{
					NSInteger loc = [parts[0] integerValue];
					NSInteger len = [parts[1] integerValue];
					NSInteger mask = [parts[2] integerValue];
					NSString* name = parts[3];
					NSColor* color = [NSColor colorWithMimsyName:name];
					if (loc + len > controller.text.length)
						len = (NSInteger) controller.text.length - loc;
					
					NSArray* managers = controller.textView.textStorage.layoutManagers;
					NSLayoutManager* layout = managers[0];
					[layout addTemporaryAttribute:NSUnderlineStyleAttributeName value:@(mask) forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
					[layout addTemporaryAttribute:NSUnderlineColorAttributeName value:color forCharacterRange:NSMakeRange((NSUInteger)loc, (NSUInteger)len)];
				}
			}];

		_colNumFile = [self _createReadWriter:@"column-number"
			readBlock:^NSString* (TextController* controller)
			{
				NSRange range = controller.textView.selectedRange;
				NSUInteger loc = range.location;
				while (loc > 0 && [controller.text characterAtIndex:loc-1] != '\n')
					--loc;
				return [NSString stringWithFormat:@"%lu", range.location - loc + 1];
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				// Find the start of the line.
				NSUInteger loc = controller.textView.selectedRange.location;
				while (loc > 0 && [controller.text characterAtIndex:loc-1] != '\n')
					--loc;
				
				// Jump to the column, but don't go past the end of the line.
				NSInteger col = [text integerValue];
				while (loc < controller.text.length && [controller.text characterAtIndex:loc] != '\n' && col > 1)
				{
					--col;
					++loc;
				}
				
				NSRange range = NSMakeRange(loc, 0);
				[controller.textView setSelectedRange:range];
				
				range = NSMakeRange(loc, 1);
				[controller.textView scrollRangeToVisible:range];
				[controller.textView showFindIndicatorForRange:range];
			}];
		
		_elementNameFile = [self _createReader:@"element-name"
			readBlock:^NSString* (TextController* controller) {return [controller getElementNameFor:controller.textView.selectedRange];}];
		
		_elementNamesFile = [self _createReader:@"element-names"
			readBlock:^NSString* (TextController* controller) {return [controller getElementNames];}];
		
		_keyStoreFile = [self _createKeyStore:@"key-values"];
		
        _languageFile = [self _createReader:@"language"
                                  readBlock:^NSString* (TextController* controller) {return controller.language ? controller.language.name : @"";}];
        
		_lengthFile = [self _createReader:@"length"
			readBlock:^NSString* (TextController* controller) {return [NSString stringWithFormat:@"%lu", controller.text.length];}];

		_lineNumFile = [self _createReadWriter:@"line-number"
			readBlock:^NSString* (TextController* controller)
			{
				int startLine = 1;
				NSUInteger i;
				NSString* text = controller.text;
				NSUInteger loc = controller.textView.selectedRange.location;
				for (i = 0; i < text.length && i < loc; i++)
				{
					if ([text characterAtIndex:i] == '\n')
						++startLine;
				}
				
				int endLine = startLine;
				loc = controller.textView.selectedRange.location + controller.textView.selectedRange.length;
				for (; i < text.length && i < loc; i++)
				{
					if ([text characterAtIndex:i] == '\n')
						++endLine;
				}
				return startLine == endLine ? [NSString stringWithFormat:@"%d", startLine] : @"-1";
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSUInteger i = 0;
				NSInteger currentLine = 1;
				NSInteger targetLine = [text integerValue];
				while (i < controller.text.length && currentLine < targetLine)
				{
					if ([controller.text characterAtIndex:i] == '\n')
						++currentLine;
					++i;
				}
				
				NSUInteger j = i;
				while (j < controller.text.length && [controller.text characterAtIndex:j] != '\n')
				{
					++j;
				}
				
				NSRange range = NSMakeRange(i, 0);
				[controller.textView setSelectedRange:range];
				
				range = NSMakeRange(i, j-i+1);
				[controller.textView scrollRangeToVisible:range];
				[controller.textView showFindIndicatorForRange:range];
			}];

		_lineSelectionFile = [self _createReader:@"line-selection"
			readBlock:^NSString* (TextController* controller)
			{
				NSUInteger start, end;
				[controller.text getLineStart:&start end:&end contentsEnd:NULL forRange:controller.textView.selectedRange];
				return [NSString stringWithFormat:@"%lu\f%lu", (unsigned long)start, (unsigned long)(end-start)];
			}];
		
		_pathFile = [self _createReader:@"path"
			readBlock:^NSString* (TextController* controller) {return controller.path;}];

		_removeTempBackColorFile = [self _createReadWriter:@"remove-temp-back-color"
			readBlock:^NSString* (TextController* controller)
			{
				UNUSED(controller);
				return @"";
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSArray* parts = [text componentsSeparatedByString:@"\f"];
				if (parts.count == 2)
				{
					NSInteger loc = [parts[0] integerValue];
					NSInteger len = [parts[1] integerValue];
					if (loc + len > controller.text.length)
						len = (NSInteger) controller.text.length - loc;
					NSRange range = NSMakeRange((NSUInteger)loc, (NSUInteger)len);

					NSArray* managers = controller.textView.textStorage.layoutManagers;
					NSLayoutManager* layout = managers[0];
					[layout removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:range];

					dispatch_queue_t main = dispatch_get_main_queue();
					dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_MSEC);
					dispatch_after(delay, main, ^{
						[layout invalidateDisplayForCharacterRange:range];
					});
				}
			}];

		_removeTempForeColorFile = [self _createReadWriter:@"remove-temp-fore-color"
			readBlock:^NSString* (TextController* controller)
			{
				UNUSED(controller);
				return @"";
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSArray* parts = [text componentsSeparatedByString:@"\f"];
				if (parts.count == 2)
				{
					NSInteger loc = [parts[0] integerValue];
					NSInteger len = [parts[1] integerValue];
					if (loc + len > controller.text.length)
						len = (NSInteger) controller.text.length - loc;
					NSRange range = NSMakeRange((NSUInteger)loc, (NSUInteger)len);
					
					NSArray* managers = controller.textView.textStorage.layoutManagers;
					NSLayoutManager* layout = managers[0];
					[layout removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:range];
					
					dispatch_queue_t main = dispatch_get_main_queue();
					dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_MSEC);
					dispatch_after(delay, main, ^{
						[layout invalidateDisplayForCharacterRange:range];
					});
				}
			}];
		
		_removeTempStrikeThroughFile = [self _createReadWriter:@"remove-temp-strike-through"
			readBlock:^NSString* (TextController* controller)
			{
				UNUSED(controller);
				return @"";
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSArray* parts = [text componentsSeparatedByString:@"\f"];
				if (parts.count == 2)
				{
					NSInteger loc = [parts[0] integerValue];
					NSInteger len = [parts[1] integerValue];
					if (loc + len > controller.text.length)
						len = (NSInteger) controller.text.length - loc;
					NSRange range = NSMakeRange((NSUInteger)loc, (NSUInteger)len);

					NSArray* managers = controller.textView.textStorage.layoutManagers;
					NSLayoutManager* layout = managers[0];
					[layout removeTemporaryAttribute:NSStrikethroughStyleAttributeName forCharacterRange:range];
					[layout removeTemporaryAttribute:NSStrikethroughColorAttributeName forCharacterRange:range];

					dispatch_queue_t main = dispatch_get_main_queue();
					dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_MSEC);
					dispatch_after(delay, main, ^{
						[layout invalidateDisplayForCharacterRange:range];
					});
				}
			}];

		_removeTempUnderlineFile = [self _createReadWriter:@"remove-temp-underline"
			readBlock:^NSString* (TextController* controller)
			{
				UNUSED(controller);
				return @"";
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSArray* parts = [text componentsSeparatedByString:@"\f"];
				if (parts.count == 2)
				{
					NSInteger loc = [parts[0] integerValue];
					NSInteger len = [parts[1] integerValue];
					if (loc + len > controller.text.length)
						len = (NSInteger) controller.text.length - loc;
					NSRange range = NSMakeRange((NSUInteger)loc, (NSUInteger)len);
					
					NSArray* managers = controller.textView.textStorage.layoutManagers;
					NSLayoutManager* layout = managers[0];
					[layout removeTemporaryAttribute:NSUnderlineStyleAttributeName forCharacterRange:range];
					[layout removeTemporaryAttribute:NSUnderlineColorAttributeName forCharacterRange:range];
					
					dispatch_queue_t main = dispatch_get_main_queue();
					dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_MSEC);
					dispatch_after(delay, main, ^{
						[layout invalidateDisplayForCharacterRange:range];
					});
				}
			}];
		
		_selectionRangeFile = [self _createReadWriter:@"selection-range"
			readBlock:^NSString* (TextController* controller)
			{
				NSRange range = controller.textView.selectedRange;
				return [NSString stringWithFormat:@"%lu\f%lu", (unsigned long)range.location, (unsigned long)range.length];
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSArray* parts = [text componentsSeparatedByString:@"\f"];
				if (parts.count == 2)
				{
					NSInteger loc = [parts[0] integerValue];
					NSInteger len = [parts[1] integerValue];
					if (loc + len > controller.text.length)
						len = (NSInteger) controller.text.length - loc;
					
					NSRange range = NSMakeRange((NSUInteger)loc, (NSUInteger)len);
					dispatch_queue_t main = dispatch_get_main_queue();
					dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_MSEC);
					dispatch_after(delay, main, ^{
						// We need to defer this in order for scrollRangeToVisible to work
						// reliably (e.g. for option-tab).
						[controller.textView setSelectedRange:range];
						[controller.textView scrollRangeToVisible:range];
						[controller.textView showFindIndicatorForRange:range];
					});
				}
			}];
		
		_selectionTextFile = [self _createReadWriter:@"selection-text"
			readBlock:^NSString* (TextController* controller)
			{
			  NSRange range = controller.textView.selectedRange;
			  return [controller.text substringWithRange:range];
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
			  NSRange range = controller.textView.selectedRange;
			  if ([controller.textView shouldChangeTextInRange:range replacementString:text])
			  {
				  [controller.textView replaceCharactersInRange:range withString:text];
				  if (text.length > 0)
					  [controller.textView.undoManager setActionName:@"Replace Text"];
				  else
					  [controller.textView.undoManager setActionName:@"Delete Text"];
				  [controller.textView didChangeText];
			  }
			}];

		_textFile = [self _createReadWriter:@"text"
			readBlock:^NSString* (TextController* controller)
			{
				return controller.text;
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				NSRange range = NSMakeRange(0, controller.text.length);
				if ([controller.textView shouldChangeTextInRange:range replacementString:text])
				{
					[controller.textView replaceCharactersInRange:range withString:text];
					if (text.length > 0)
						[controller.textView.undoManager setActionName:@"Replace Text"];
					else
						[controller.textView.undoManager setActionName:@"Delete Text"];
					[controller.textView didChangeText];
				}
			}];

		_titleFile = [self _createReader:@"title"
			readBlock:^NSString* (TextController* controller) {return controller.window.title;}];
		
		_wordWrapFile = [self _createReadWriter:@"word-wrap"
			readBlock:^NSString* (TextController* controller)
			{
				return controller.isWordWrapping ? @"true" : @"false";
			}
			writeBlock:^(TextController* controller, NSString* text)
			{
				bool wrap = [text isEqualToString:@"true"];
				if (wrap != controller.isWordWrapping)
				{
					[controller toggleWordWrap];
				}
			}];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_mainChanged:) name:NSWindowDidBecomeMainNotification object:nil];
	}
	return self;
}

- (TextController*)frontmost
{
	TextController* controller = _frontmost;
	return controller;
}

- (void)onSelectionChanged:(TextController*)controller
{
	if (controller == _frontmost)
	{
        [_colNumFile notifyIfChangedNonBlocking];
        [_lineNumFile notifyIfChangedNonBlocking];				// TODO: this seems awfully slow
        [_lineSelectionFile notifyIfChangedNonBlocking];
        [_selectionRangeFile notifyIfChangedNonBlocking];
        [_selectionTextFile notifyIfChangedNonBlocking];
	}
}

- (void)onTextChanged:(TextController*)controller
{
	if (controller == _frontmost)
	{
        [_selectionTextFile notifyIfChangedNonBlocking];
        [_textFile notifyIfChangedNonBlocking];			// TODO: watching this can be expensive for large files, could maybe use a custom proc file class
	}
}

- (void)onWordWrapChanged:(TextController*)controller
{
	if (controller == _frontmost)
        [_wordWrapFile notifyIfChangedNonBlocking];
}

- (void)onAppliedStyles:(TextController*)controller
{
    if (controller == _frontmost)
    {
        dispatch_queue_t main = dispatch_get_main_queue();
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 0*NSEC_PER_MSEC);
        dispatch_after(delay, main, ^{
            [Extensions invokeBlocking:@"/text-document/applied-styles"];
        });
    }
}

- (ProcFileReader*)_createReader:(NSString*)name readBlock:(NSString* (^)(TextController*))readBlock
{
	ProcFileReader* file = nil;
	
	AppDelegate* app = (AppDelegate*) [NSApp delegate];
	ProcFileSystem* fs = app.procFileSystem;
	if (fs)
	{
		file = [[ProcFileReader alloc]
				  initWithDir:^NSString *{return @"/text-document";}
				  fileName:name
				  readStr:^NSString *
				  {
					  TextController* controller = _frontmost;
					  return controller ? readBlock(controller) : @"";
				  }];
		[fs addReader:file];
	}
	
	return file;
}
						
- (ProcFileReadWrite*)_createReadWriter:(NSString*)name readBlock:(NSString* (^)(TextController*))readBlock writeBlock:(void (^)(TextController*, NSString*))writeBlock
{
	ProcFileReadWrite* file = nil;
	
	AppDelegate* app = (AppDelegate*) [NSApp delegate];
	ProcFileSystem* fs = app.procFileSystem;
	if (fs)
	{
		file = [[ProcFileReadWrite alloc]
					initWithDir:^NSString *{return @"/text-document";}
					fileName:name
					readStr:^NSString*
					{
						TextController* controller = _frontmost;
						return controller ? readBlock(controller) : @"";
					}
					writeStr:^(NSString* text)
					{
						TextController* controller = _frontmost;
						if (controller)
							writeBlock(controller, text);
					}];
		[fs addWriter:file];
	}
	
	return file;
}

- (ProcFileKeyStoreRW*)_createKeyStore:(NSString*)name
{
	ProcFileKeyStoreRW* file = nil;
	
	AppDelegate* app = (AppDelegate*) [NSApp delegate];
	ProcFileSystem* fs = app.procFileSystem;
	if (fs)
	{
		file = [[ProcFileKeyStoreRW alloc] initWithDir:^NSString*
			 {
				 return [NSString stringWithFormat:@"/text-document/%@", name];
			 }];
		[fs addWriter:file];
	}
	
	return file;
}

- (void)_mainChanged:(NSNotification*)notification
{
	// Couple points:
	// 1) We don't use NSApp orderedWindows because it was a major bottleneck.
	// 2) We don't reset _frontmost because we want the frontmost text document,
	// not the main window.
    TextController* oldFront = _frontmost;
    
    NSWindow* window = notification.object;
	if (window.windowController)
		if ([window.windowController isKindOfClass:[TextController class]])
			_frontmost = window.windowController;
    
    if (_frontmost && _frontmost != oldFront)
        [Extensions invokeNonBlocking:@"/text-document/main-changed"];
}

@end


