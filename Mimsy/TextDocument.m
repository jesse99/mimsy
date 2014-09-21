#import "TextDocument.h"

#import "Decode.h"
#import "Extensions.h"
#import "FunctionalTest.h"
#import "InfoController.h"
#import "Metadata.h"
#import "TextController.h"
#import "TextView.h"
#import "TranscriptController.h"
#import "Utils.h"

static NSString* BOM = @"\uFEFF";			// Cocoa considers this a control character

// We can't use a dict literal because the keys are not compile time constants.
static NSDictionary* controlNames()
{
	static NSMutableDictionary* names = nil;
	
	if (names == nil)
	{
		names = [NSMutableDictionary new];
		
		// See http://www.fileformat.info/info/unicode/category/Cc/list.htm
		names[[NSNumber numberWithUnsignedInt:0x00]] = @"NULL";
		names[[NSNumber numberWithUnsignedInt:0x01]] = @"START OF HEADING";
		names[[NSNumber numberWithUnsignedInt:0x02]] = @"START OF TEXT";
		names[[NSNumber numberWithUnsignedInt:0x03]] = @"END OF TEXT";
		names[[NSNumber numberWithUnsignedInt:0x04]] = @"END OF TRANSMISSION";
		names[[NSNumber numberWithUnsignedInt:0x05]] = @"ENQUIRY";
		names[[NSNumber numberWithUnsignedInt:0x06]] = @"ACKNOWLEDGE";
		names[[NSNumber numberWithUnsignedInt:0x07]] = @"BELL";
		names[[NSNumber numberWithUnsignedInt:0x08]] = @"BACKSPACE";
		names[[NSNumber numberWithUnsignedInt:0x09]] = @"CHARACTER TABULATION";
		names[[NSNumber numberWithUnsignedInt:0x0A]] = @"LINE FEED";
		names[[NSNumber numberWithUnsignedInt:0x0B]] = @"LINE TABULATION";
		names[[NSNumber numberWithUnsignedInt:0x0C]] = @"FORM FEED";
		names[[NSNumber numberWithUnsignedInt:0x0D]] = @"CARRIAGE RETURN";
		names[[NSNumber numberWithUnsignedInt:0x0E]] = @"SHIFT OUT";
		names[[NSNumber numberWithUnsignedInt:0x0F]] = @"SHIFT IN";
		names[[NSNumber numberWithUnsignedInt:0x10]] = @"DATA LINK ESCAPE";
		names[[NSNumber numberWithUnsignedInt:0x11]] = @"DEVICE CONTROL ONE";
		names[[NSNumber numberWithUnsignedInt:0x12]] = @"DEVICE CONTROL TWO";
		names[[NSNumber numberWithUnsignedInt:0x13]] = @"DEVICE CONTROL THREE";
		names[[NSNumber numberWithUnsignedInt:0x14]] = @"DEVICE CONTROL FOUR";
		names[[NSNumber numberWithUnsignedInt:0x15]] = @"NEGATIVE ACKNOWLEDGE";
		names[[NSNumber numberWithUnsignedInt:0x16]] = @"SYNCHRONOUS IDLE";
		names[[NSNumber numberWithUnsignedInt:0x17]] = @"END OF TRANSMISSION BLOCK";
		names[[NSNumber numberWithUnsignedInt:0x18]] = @"CANCEL";
		names[[NSNumber numberWithUnsignedInt:0x19]] = @"END OF MEDIUM";
		names[[NSNumber numberWithUnsignedInt:0x1A]] = @"SUBSTITUTE";
		names[[NSNumber numberWithUnsignedInt:0x1B]] = @"ESCAPE";
		names[[NSNumber numberWithUnsignedInt:0x1C]] = @"INFORMATION SEPARATOR FOUR";
		names[[NSNumber numberWithUnsignedInt:0x1D]] = @"INFORMATION SEPARATOR THREE ";
		names[[NSNumber numberWithUnsignedInt:0x1E]] = @"INFORMATION SEPARATOR TWO";
		names[[NSNumber numberWithUnsignedInt:0x1F]] = @"INFORMATION SEPARATOR ONE";
		
		names[[NSNumber numberWithUnsignedInt:0x7F]] = @"DELETE";
		names[[NSNumber numberWithUnsignedInt:0x80]] = @"unnamed control";
		names[[NSNumber numberWithUnsignedInt:0x81]] = @"unnamed control";
		names[[NSNumber numberWithUnsignedInt:0x82]] = @"BREAK PERMITTED HERE";
		names[[NSNumber numberWithUnsignedInt:0x83]] = @"NO BREAK HERE";
		names[[NSNumber numberWithUnsignedInt:0x84]] = @"unnamed control";
		names[[NSNumber numberWithUnsignedInt:0x85]] = @"NEXT LINE";
		names[[NSNumber numberWithUnsignedInt:0x86]] = @"START OF SELECTED AREA";
		names[[NSNumber numberWithUnsignedInt:0x87]] = @"END OF SELECTED AREA";
		names[[NSNumber numberWithUnsignedInt:0x88]] = @"CHARACTER TABULATION SET";
		names[[NSNumber numberWithUnsignedInt:0x89]] = @"CHARACTER TABULATION WITH JUSTIFICATION";
		names[[NSNumber numberWithUnsignedInt:0x8A]] = @"LINE TABULATION SET";
		names[[NSNumber numberWithUnsignedInt:0x8B]] = @"PARTIAL LINE FORWARD";
		names[[NSNumber numberWithUnsignedInt:0x8C]] = @"PARTIAL LINE BACKWARD";
		names[[NSNumber numberWithUnsignedInt:0x8D]] = @"REVERSE LINE FEED";
		names[[NSNumber numberWithUnsignedInt:0x8E]] = @"SINGLE SHIFT TWO";
		names[[NSNumber numberWithUnsignedInt:0x8F]] = @"SINGLE SHIFT THREE";
		names[[NSNumber numberWithUnsignedInt:0x90]] = @"DEVICE CONTROL STRING";
		names[[NSNumber numberWithUnsignedInt:0x91]] = @"PRIVATE USE ONE";
		names[[NSNumber numberWithUnsignedInt:0x92]] = @"PRIVATE USE TWO";
		names[[NSNumber numberWithUnsignedInt:0x93]] = @"SET TRANSMIT STATE";
		names[[NSNumber numberWithUnsignedInt:0x94]] = @"CANCEL CHARACTER";
		names[[NSNumber numberWithUnsignedInt:0x95]] = @"MESSAGE WAITING";
		names[[NSNumber numberWithUnsignedInt:0x96]] = @"START OF GUARDED AREA";
		names[[NSNumber numberWithUnsignedInt:0x97]] = @"END OF GUARDED AREA";
		names[[NSNumber numberWithUnsignedInt:0x98]] = @"START OF STRING";
		names[[NSNumber numberWithUnsignedInt:0x99]] = @"unnamed control";
		names[[NSNumber numberWithUnsignedInt:0x9A]] = @"SINGLE CHARACTER INTRODUCER";
		names[[NSNumber numberWithUnsignedInt:0x9B]] = @"CONTROL SEQUENCE INTRODUCER";
		names[[NSNumber numberWithUnsignedInt:0x9C]] = @"STRING TERMINATOR";
		names[[NSNumber numberWithUnsignedInt:0x9D]] = @"OPERATING SYSTEM COMMAND";
		names[[NSNumber numberWithUnsignedInt:0x9E]] = @"PRIVACY MESSAGE";
		names[[NSNumber numberWithUnsignedInt:0x9F]] = @"APPLICATION PROGRAM COMMAND";
	}
	
	return names;
}

static enum LineEndian getEndian(NSString* text, bool* hasMac, bool* hasWindows)
{
	int counts[4] = {0};
	*hasWindows = false;
	*hasMac = false;
		
	// It's annoying to scan the entire string for line endings, but in the common
	// case where we are dealing with Unix files we need to scan the entire file
	// to ensure that there are no line endings we need to fix.
	NSUInteger i = 0;
	NSUInteger len = [text length];
	while (i < len)
	{
		unichar ch = [text characterAtIndex:i];
		if (i + 1 < len && ch == '\r' && [text characterAtIndex:i+1] == '\n')
		{
			*hasWindows = true;
			counts[WindowsEndian] += 1;
			i += 2;
		}
		else if (ch == '\r')
		{
			*hasMac = true;
			counts[MacEndian] += 1;
			i += 1;
		}
		else if (ch == '\n')
		{
			counts[UnixEndian] += 1;
			i += 1;
		}
		else
		{
			i += 1;
		}
	}

	// Set the endian to whichever is the most common.
	if (counts[WindowsEndian] > counts[MacEndian] && counts[WindowsEndian] > counts[UnixEndian])
		return WindowsEndian;
	
	else if (counts[MacEndian] > counts[WindowsEndian] && counts[MacEndian] > counts[UnixEndian])
		return MacEndian;
	
	else
		return UnixEndian;
}

@implementation TextDocument
{
	TextController* _controller;
	InfoController* _info;
	enum LineEndian _endian;
	NSStringEncoding _encoding;
	NSURL* _url;
}

- (id)init
{
    self = [super init];
    if (self)
	{
		_endian = UnixEndian;
		updateInstanceCount(@"TextDocument", +1);
    }
    return self;
}

- (void)dealloc
{
	updateInstanceCount(@"TextDocument", -1);
}

- (void)makeWindowControllers
{
	_controller = [[TextController alloc] init];
	[self addWindowController:_controller];
}

- (void)controllerDidLoad
{
	ASSERT([_controller textView]);

	_url = [self fileURL];
	
	if (self.text)
	{
		[_controller setAttributedText:self.text];
		_text = nil;
	}
	[_controller onPathChanged];		// have to do this after getting text
	[self readMetataDataFrom:self.fileURL.path];
	
	[_controller open];
}

// This is called every time the document is saved.
- (void)setFileURL:(NSURL *)url
{
	[super setFileURL:url];
	
	LOG("Text:Verbose", "Set file URL to %s", STR(url));
	if (_controller && ![url isEqual:_url])
	{
		_url = url;
		[_controller onPathChanged];
	}
}

// The good:
// 1) There's no annoying extra file hanging about while the document is unsaved.
// 2) The window title includes a nifty " - Edited" suffix when the document is unsaved.
// 3) The document is auto-saved to the right place so stuff like scripts should pretty
// much always have the latest info even without an explicit save.
//
// The bad:
// 1) The document is auto-saved to the right place. I think this is normally what you
// want but it can be a bit disconcerting: there's no prompt to save and no opportunity
// to review changes.
//
// Note that BaseInFiles depends upon this behavior.
+ (BOOL)autosavesInPlace
{
    return YES;	// TODO: make this an option? a setting?
}

// Continuum popped up a sheet if the document was edited and another process had changed it.
// However this doesn't appear to be neccesary with autosavesInPlace. (And with autosavesInPlace
// off the Continuum code doesn't work quite right because when Appkit pops up an annoying
// alert on save that I haven't figured out how to get rid of).
- (void)reloadIfChanged
{
	if ([self hasChangedOnDisk])
	{
		[self reload];
	}
}

- (void)reload
{
	NSString* type = [self fileType];
	NSURL* url = [self fileURL];
	LOG("Text", "Reloading document from %s", STR(url));
	
	NSError* error = nil;
	BOOL read = [self revertToContentsOfURL:url ofType:type error:&error];
	if (!read)
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't reload %@:\n%@.", url, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
	}
	
	ASSERT(self.text == nil);
	[_controller open];
}

- (bool)hasChangedOnDisk
{
	bool changed = false;
	
	NSURL* url = [self fileURL];
	if (url != nil)
	{
		NSDate* docTime = [self fileModificationDate];
		
		NSError* error = nil;
		NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:&error];
		if (attrs)
		{
			NSDate* fileTime = attrs[NSFileModificationDate];
			
			if (fileTime != nil && [fileTime compare:docTime] == NSOrderedDescending)
			{
				LOG("Text:Verbose", "Document %s changed on disk", STR(url));
				changed = true;
			}
		}
	}
		
	return changed;
}

- (TextFormat)format
{
	TextFormat result = PlainTextFormat;
	
	NSString* desc = self.fileType;
	if (desc)
	{
		if ([desc hasPrefix:@"Plain Text"] || [desc isEqualToString:@"binary"])
			result = PlainTextFormat;
		
		else if ([desc isEqualToString:@"HTML"])
			result = HTMLFormat;
		
		else if ([desc isEqualToString:@"Rich Text Format (RTF)"])
			result = RTFFormat;
		
		else if ([desc isEqualToString:@"Word 97 Format (doc)"])
			result = Word97Format;
		
		else if ([desc isEqualToString:@"Word 2007 Format (docx)"])
			result = Word2007Format;
		
		else if ([desc isEqualToString:@"Open Document Text (odt)"])
			result = OpenDocFormat;

		else
			ASSERT_MESG("unknown file type: %s", STR(desc));
	}
	
	return result;
}

- (void)setFormat:(enum TextFormat)format
{
	if (format != self.format)
	{
		switch (format)
		{
			case PlainTextFormat:
				[self setFileType:@"Plain Text, UTF8 Encoded"];
				break;
				
			case RTFFormat:
				[self setFileType:@"Rich Text Format (RTF)"];
				break;
				
			case HTMLFormat:
				[self setFileType:@"HTML"];
				break;
				
			case Word97Format:
				[self setFileType:@"Word 97 Format (doc)"];
				break;
				
			case Word2007Format:
				[self setFileType:@"Word 2007 Format (docx)"];
				break;
				
			case OpenDocFormat:
				[self setFileType:@"Open Document Text (odt)"];
				break;
				
			default:
				ASSERT_MESG("bad format: %lu", format);
				
		}
		[self updateChangeCount:NSChangeDone];
	}
}

- (enum LineEndian)endian
{
	return _endian;
}

- (void)setEndian:(enum LineEndian)endian
{
	if (endian != _endian)
	{
		_endian = endian;
		[self updateChangeCount:NSChangeDone];
	}
}

- (NSStringEncoding)encoding
{
	return _encoding;
}

- (void)setEncoding:(NSStringEncoding)encoding
{
	if (encoding != _encoding)
	{
		_encoding = encoding;
		[self updateChangeCount:NSChangeDone];
	}
}

- (void)getInfo:(id)sender
{
	UNUSED(sender);
	
	if (_info)
	{
		[_info showWindow:self];
	}
	else
	{
		_info = [InfoController openFor:self];	// we have to retain a reference to the window or it will poof
		[[NSNotificationCenter defaultCenter] addObserverForName:NSWindowWillCloseNotification object:_info.window queue:nil usingBlock:
		 ^(NSNotification* notification)
		 {
			 UNUSED(notification);
			 [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:_info.window];
			 _info = nil;
		 }
		 ];
	}
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	ASSERT(self.text == nil);
	ASSERT(outError != NULL);
	
	_encoding = 0;
	_binary = false;
	*outError = nil;
	LOG("Text:Verbose", "Reading document from %s", STR(self.fileURL));
	
	const NSUInteger MaxBytes = 512*1024;		// I think this is around 16K lines of source
	if ([data length] > MaxBytes)
		[self confirmOpen:data error:outError];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"ReadingTextDocument" object:self];

	if (*outError == nil)
		[self doReadFromData:data ofType:typeName error:outError];
	
	if (*outError == nil && self.fileURL && _controller)
		[self readMetataDataFrom:self.fileURL.path];
	
	return *outError == nil;
}

- (bool)confirmOpen:(NSData *)data error:(NSError **)outError
{
	ASSERT(outError != NULL);
	
	NSString* name = [[self fileURL] lastPathComponent];
	NSString* mesg = [[NSString alloc] initWithFormat:@"This file is %@. Are you sure you want to open it?", [Utils bytesToStr:data.length]];

	NSAlert* alert = [NSAlert new];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert setInformativeText:name];
	[alert setMessageText:mesg];
	[alert addButtonWithTitle:@"No"];
	[alert addButtonWithTitle:@"Yes"];
	
	NSInteger button = [alert runModal];
	if (button == NSAlertSecondButtonReturn)
	{
		*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
	}
	return *outError == NULL;
}

- (bool)doReadFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	ASSERT(outError != NULL);
	
	_endian = NoEndian;
	
	if ([typeName isEqualToString:@"Plain Text, UTF8 Encoded"] || [typeName isEqualToString:@"HTML"])
	{
		Decode* decode = [[Decode alloc] initWithData:data];
		NSMutableString* text = decode.text;
		if (text)
		{
			bool hasMac, hasWindows;
			_endian = getEndian(text, &hasMac, &hasWindows);
			_encoding = decode.encoding;
			
			if (self.encoding == NSMacOSRomanStringEncoding)
				[TranscriptController writeError:@"Read the file as Mac OS Roman (it isn't utf-8, utf-16, or utf-32)."];
			
			// To make life easier on ourselves text documents in memory are always
			// unix endian (this will also fixup files with mixed line endings).
			if (hasWindows)
				[text replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, [text length])];
			
			if (hasMac)
				[text replaceOccurrencesOfString:@"\r" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, [text length])];
			
			[self checkForControlChars:text];
			_text = [[NSMutableAttributedString alloc] initWithString:text];
			
			// If an html file is being edited in Mimsy then ensure that it is saved
			// as plain text. (To save a document as html the user needs to use save as
			// and explicitly select html).
			[self setFileType:@"Plain Text, UTF8 Encoded"];
		}
		else
		{
			NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:[decode error]};
			*outError = [NSError errorWithDomain:@"mimsy" code:1 userInfo:dict];
		}
	}
	else if ([typeName isEqualToString:@"Rich Text Format (RTF)"])
	{
		NSDictionary* options = @{NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType};
		_text = [[NSMutableAttributedString alloc] initWithData:data options:options documentAttributes:NULL error:outError];
	}
	else if ([typeName isEqualToString:@"Word 97 Format (doc)"])
	{
		NSDictionary* options = @{NSDocumentTypeDocumentAttribute:NSDocFormatTextDocumentType};
		_text = [[NSMutableAttributedString alloc] initWithData:data options:options documentAttributes:NULL error:outError];
	}
	else if ([typeName isEqualToString:@"Word 2007 Format (docx)"])
	{
		// There is also NSWordMLTextDocumentType, but that is an older (2003) XML format.
		NSDictionary* options = @{NSDocumentTypeDocumentAttribute:NSOfficeOpenXMLTextDocumentType};
		_text = [[NSMutableAttributedString alloc] initWithData:data options:options documentAttributes:NULL error:outError];
	}
	else if ([typeName isEqualToString:@"Open Document Text (odt)"])
	{
		NSDictionary* options = @{NSDocumentTypeDocumentAttribute:NSOpenDocumentTextDocumentType};
		_text = [[NSMutableAttributedString alloc] initWithData:data options:options documentAttributes:NULL error:outError];
	}
	else if ([typeName isEqualToString:@"binary"])
	{
		NSString* str = [Utils bufferToStr:data.bytes length:data.length];
		_text = [[NSMutableAttributedString alloc] initWithString:str];
		_binary = true;
	}
	else
	{
		ASSERT_MESG("bad typeName: %s", STR(typeName)); NSAssert(false, @"");
	}

	if (self.text && _controller)
	{
		// This path is taken for revert, but not for the initial open.
		[_controller setAttributedText:self.text];
		_text = nil;
	}
	
	// We don't have a dual for the saving proc file because we don't have a controller when
	// opening a brand new document. Probably what we should do is have a file to watch for
	// newly opened windows (could do this in the controllers).
	
	return *outError == NULL;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{	
	NSData* data = nil;
	NSTextView* textv = _controller.textView;
	if (textv)
	{
		NSString* path = [NSString stringWithFormat:@"%@/saving", [_controller getProcFilePath]];
		(void) [Extensions invoke:path];

		NSTextStorage* storage = [textv textStorage];
		NSMutableString* str = [storage mutableString];
		LOG("Text", "Saving document to %s", STR(self.fileURL));
		
		if ([typeName isEqualToString:@"Plain Text, UTF8 Encoded"])
		{
			// This is more like the default plain text type: when loading a document that is not
			// rtf or word or whatever this typename will be chosen via the plist. However the actual
			// encoding is inferred from the contents of the file (or set via the Get Info panel).
			if (!_encoding)
				_encoding = NSUTF8StringEncoding;
			[self restoreEndian:str];
			[self checkForControlChars:str];
			data = [str dataUsingEncoding:self.encoding allowLossyConversion:YES];
		}
		else if ([typeName isEqualToString:@"Plain Text, UTF16 Encoded"])
		{
			// This case is only used when the user selects save as and then the utf16 encoding.
			_encoding = NSUTF16LittleEndianStringEncoding;
			[self restoreEndian:str];
			[self checkForControlChars:str];
			data = [str dataUsingEncoding:self.encoding allowLossyConversion:YES];
		}
		else if ([typeName isEqualToString:@"HTML"])
		{
			NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType};
			[self restoreEndian:str];
			[self checkForControlChars:str];
			data = [storage dataFromRange:NSMakeRange(0, storage.length) documentAttributes:attrs error:outError];
		}
		else if ([typeName isEqualToString:@"Rich Text Format (RTF)"])
		{
			NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType};
			data = [storage dataFromRange:NSMakeRange(0, storage.length) documentAttributes:attrs error:outError];
		}
		else if ([typeName isEqualToString:@"Word 97 Format (doc)"])
		{
			NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute:NSDocFormatTextDocumentType};
			data = [storage dataFromRange:NSMakeRange(0, storage.length) documentAttributes:attrs error:outError];
		}
		else if ([typeName isEqualToString:@"Word 2007 Format (docx)"])
		{
			NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute:NSOfficeOpenXMLTextDocumentType};
			data = [storage dataFromRange:NSMakeRange(0, storage.length) documentAttributes:attrs error:outError];
		}
		else if ([typeName isEqualToString:@"Open Document Text (odt)"])
		{
			NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute:NSOpenDocumentTextDocumentType};
			data = [storage dataFromRange:NSMakeRange(0, storage.length) documentAttributes:attrs error:outError];
		}
		else
		{
			ASSERT_MESG("bad typeName: %s", STR(typeName));
		}
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"TextDocumentSaved" object:self];

	return data;
}

// We can't save metadata in dataOfType: because it winds up in the temp file
// and doesn't get copied over when the file is moved to the correct location.
// Dunno if this is the best approach but to work around this we override the
// last method called during document saving.
- (void)setFileModificationDate:(NSDate*)modificationDate
{
	[super setFileModificationDate:modificationDate];
	if (self.fileURL && self.isDocumentEdited)			// need to check for edited because this is also called on open
		[self saveMetataDataTo:self.fileURL.path];
}

- (void)saveMetataDataTo:(NSString*)path
{
	// If the document has a language then the back color is set via the
	// styles file so there is no need to save colors for it.
	if (!_controller.language)
	{
		NSColor* color = _controller.textView.backgroundColor;
		NSError* error = [Metadata writeCriticalDataTo:path named:@"back-color" with:color];
		if (error)
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Couldn't write metadata to '%@':\n%@.", path, reason];
			[TranscriptController writeError:mesg];
		}
	}
}

- (void)readMetataDataFrom:(NSString*)path
{
	NSError* error = nil;
	NSColor* color = [Metadata readCriticalDataFrom:path named:@"back-color" outError:&error];
	NSTextView* textv = _controller.textView;
	if (color && textv)
		[textv setBackgroundColor:color];
	else
		LOG("Text:Verbose", "Couldn't read back-color for '%s': %s", STR(path), STR([error localizedFailureReason]));
}

- (void)restoreEndian:(NSMutableString*)str
{
	NSRange range = NSMakeRange(0, str.length);
	if (self.endian == MacEndian)
		[str replaceOccurrencesOfString:@"\n" withString:@"\r" options:NSLiteralSearch range:range];
	else if (self.endian == WindowsEndian)
		[str replaceOccurrencesOfString:@"\n" withString:@"\r\n" options:NSLiteralSearch range:range];
}

// It is fairly rare for control characters to wind up in text files, but when it does happen
// it can be quite annoying, especially because they cannot ordinarily be seen. So, if this
// happens we'll write a message to the transcript window to alert the user.
- (void)checkForControlChars:(NSString*)text
{
	int numGremlines = 0;
	NSDictionary* chars = [self findControlChars:text outCount:&numGremlines];
	
	if (chars.count > 0)
	{
		NSString* file = [[[self fileURL] path] lastPathComponent];
		
		NSString* mesg;
		if (chars.count <= 5)
			mesg = [[NSString alloc] initWithFormat:@"Found %@ in %@.", [self charsToString:chars], file];
		else
			mesg = [[NSString alloc] initWithFormat:@"Found %d control characters of %lu different types in %@.", numGremlines, chars.count, file];
		
		[TranscriptController writeError:mesg];
	}
}

// Returns a dict where the key is a control character and the value the
// number of times it has appeared.
- (NSDictionary*)findControlChars:(NSString*)str outCount:(int*)count
{
	NSMutableDictionary* chars = [NSMutableDictionary new];
	
	NSUInteger len = str.length;
	NSRange range = NSMakeRange(0, len);
	id controlChars = [NSCharacterSet controlCharacterSet];
	while (true)
	{
		NSRange temp = [str rangeOfCharacterFromSet:controlChars options:NSLiteralSearch range:range];
		if (temp.length == 0)
			break;
		
		unichar ch = [str characterAtIndex:temp.location];
		if (ch != '\r' && ch != '\n' && ch != '\t' && ch != [BOM characterAtIndex:0])
		{
			NSNumber* key = [NSNumber numberWithUnsignedInt:ch];
			id value = chars[key];
			if (value)
				chars[key] = [NSNumber numberWithInt:([value intValue] + 1)];
			else
				chars[key] = [NSNumber numberWithInt:1];
			*count += 1;
		}
		
		range = NSMakeRange(temp.location + 1, len - (temp.location + 1));
	}
	
	return chars;
	
}

- (NSString*)charsToString:(NSDictionary*)chars
{
	NSMutableArray* strs = [NSMutableArray arrayWithCapacity:chars.count];
	
	bool plural = chars.count > 1;
	
	NSUInteger i = 0;
	NSDictionary* names = controlNames();
	for (NSNumber* ch in chars)
	{
		id name = names[ch];
		if (name)
			strs[i++] = [[NSString alloc] initWithFormat:@"%@ '\\x%.2X' (%@)", chars[ch], [ch intValue], name];
		else
			strs[i++] = [[NSString alloc] initWithFormat:@"%@ '\\x%.2X' (?)", chars[ch], [ch intValue]];
		
		if ([chars[ch] intValue] > 1)
			plural = true;
	}
	
	NSMutableString* result = [NSMutableString new];
	[result appendString:[strs componentsJoinedByString:@" and "]];
	[result appendString:(plural ? @" characters" : @" character")];
	return result;
}

@end
