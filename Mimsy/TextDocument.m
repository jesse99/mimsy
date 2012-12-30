#import "TextDocument.h"

#import "Decode.h"
#import "Logger.h"
#import "TextController.h"
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
	NSURL* _url;
}

- (id)init
{
    self = [super init];
    if (self)
	{
		_endian = UnixEndian;
    }
    return self;
}

- (void)makeWindowControllers
{
	_controller = [[TextController alloc] init];
	[self addWindowController:_controller];
}

- (void)controllerDidLoad
{
	NSAssert([_controller textView], @"%@ has a nil view", _controller);

	_url = [self fileURL];
	[_controller onPathChanged];
	
	if (self.text)
	{
		[_controller setAttributedText:self.text];
		_text = nil;
	}
	[_controller open];
}

// This is called every time the document is saved.
- (void)setFileURL:(NSURL *)url
{
	[super setFileURL:url];
	
	INFO("Text", "Writing document to %@", url);		// TODO: include the path
	if (_controller && ![url isEqual:_url])
	{
		_url = url;
		[_controller onPathChanged];
	}
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

// Continuum popped up a sheet if the ocument was edited and another process had changed it.
// However this doesn't appear to be neccesary with autosavesInPlace. (And with autosavesInPlace
// off the Continuum code doesn't work quite right because when Appkit pops up an annoying
// alert on save that I haven't figured out how to get rid of).
- (void) reloadIfChanged
{
	if ([self hasChangedOnDisk])
	{
		[self reload];
	}
}

- (void) reload
{
	NSString* type = [self fileType];
	NSURL* url = [self fileURL];
	
	NSError* error = nil;
	BOOL read = [self revertToContentsOfURL:url ofType:type error:&error];
	if (!read)
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't reload %@:\n%@.", url, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
	}
	
	NSAssert(self.text == nil, @"text wasn't nil");
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
		if (error == nil)
		{
			NSDate* fileTime = attrs[NSFileModificationDate];
			
			if (fileTime != nil && [fileTime compare:docTime] == NSOrderedDescending)
			{
				DEBUG("Text", "Focument XXX changed on disk");		// TODO: include the path
				changed = true;
			}
		}
	}
		
	return changed;

}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	NSAssert(self.text == nil, @"%@ should be nil", self.text);
	
	_encoding = 0;
	_binary = false;
	*outError = nil;
	INFO("Text", "Reading document from XXX");		// TODO: include the path
	
	const NSUInteger MaxBytes = 512*1024;		// I think this is around 16K lines of source
	if ([data length] > MaxBytes)
		[self confirmOpen:data error:outError];

	if (*outError == nil)
		[self doReadFromData:data ofType:typeName error:outError];
	
	return *outError == nil;
}

- (void)confirmOpen:(NSData *)data error:(NSError **)outError
{
	NSString* name = [[self fileURL] lastPathComponent];
	NSString* mesg = [[NSString alloc] initWithFormat:@"This file is %@. Are you sure you want to open it?", [Utils bytesToStr:data.length]];
	NSInteger button = NSRunAlertPanel(name, mesg, @"No", @"Yes", nil);
	if (button != NSAlertAlternateReturn)
	{
		*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
	}
}

- (void)doReadFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	_endian = NoEndian;
	ERROR("Text", "This isn't really an error");		// TODO: remove this
	
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
		NSAssert(false, @"readData> bad typeName: %@", typeName);
	}

	if (self.text && _controller)
	{
		// This path is taken for revert, but not for the initial open.
		[_controller setAttributedText:self.text];
		_text = nil;
	}
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{	
	NSData* data = nil;
	NSTextStorage* storage = [_controller.textView textStorage];
	NSMutableString* str = [storage mutableString];
	
	if ([typeName isEqualToString:@"Plain Text, UTF8 Encoded"])
	{
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
		NSAssert(false, @"dataOfType:error:> bad typeName: %@", typeName);
	}
	
	return data;
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
