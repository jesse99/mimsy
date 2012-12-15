#import "TextDocument.h"

#import "Decode.h"
#import "TextController.h"
#import "TranscriptController.h"
#import "Utils.h"

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
}

- (id)init
{
    self = [super init];
    if (self)
	{
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
	NSAssert([_controller view], @"%@ has a nil view", _controller);

	if (self.text)
	{
		[[[_controller view] textStorage] setAttributedString:self.text];
		self.text = nil;
	}
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	NSAssert(self.text == nil, @"%@ should be nil", self.text);
	
	self.endian = NoEndian;
	self.encoding = 0;
	self.binary = false;
	*outError = nil;
	
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
	if ([typeName isEqualToString:@"Plain Text, UTF8 Encoded"] || [typeName isEqualToString:@"HTML"])
	{
		Decode* decode = [[Decode alloc] initWithData:data];
		NSMutableString* text = decode.text;
		if (text)
		{
			bool hasMac, hasWindows;
			self.endian = getEndian(text, &hasMac, &hasWindows);
			self.encoding = decode.encoding;
			
			if (self.encoding == NSMacOSRomanStringEncoding)
				[TranscriptController writeError:@"Read the file as Mac OS Roman (it isn't utf-8, utf-16, or utf-32)."];
			
			// To make life easier on ourselves text documents in memory are always
			// unix endian (this will also fixup files with mixed line endings).
			if (hasWindows)
				[text replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, [text length])];
			
			if (hasMac)
				[text replaceOccurrencesOfString:@"\r" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, [text length])];
			
			self.text = [[NSMutableAttributedString alloc] initWithString:text];
			
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
		self.text = [[NSMutableAttributedString alloc] initWithData:data options:options documentAttributes:NULL error:outError];
	}
	else if ([typeName isEqualToString:@"Word 97 Format (doc)"])
	{
		NSDictionary* options = @{NSDocumentTypeDocumentAttribute:NSDocFormatTextDocumentType};
		self.text = [[NSMutableAttributedString alloc] initWithData:data options:options documentAttributes:NULL error:outError];
	}
	else if ([typeName isEqualToString:@"Word 2007 Format (docx)"])
	{
		// There is also NSWordMLTextDocumentType, but that is an older (2003) XML format.
		NSDictionary* options = @{NSDocumentTypeDocumentAttribute:NSOfficeOpenXMLTextDocumentType};
		self.text = [[NSMutableAttributedString alloc] initWithData:data options:options documentAttributes:NULL error:outError];
	}
	else if ([typeName isEqualToString:@"Open Document Text (odt)"])
	{
		NSDictionary* options = @{NSDocumentTypeDocumentAttribute:NSOpenDocumentTextDocumentType};
		self.text = [[NSMutableAttributedString alloc] initWithData:data options:options documentAttributes:NULL error:outError];
	}
	else if ([typeName isEqualToString:@"binary"])
	{
		NSString* str = [Utils bufferToStr:data.bytes length:data.length];
		self.text = [[NSMutableAttributedString alloc] initWithString:str];
		self.binary = true;
	}
	else
	{
		NSAssert(false, @"readData> bad typeName: %@", typeName);
	}

	if (self.text && _controller)
	{
		// This path is taken for revert, but not for the initial open.
		[[[_controller view] textStorage] setAttributedString:self.text];
		self.text = nil;
	}
}

// TODO:
// save as
// restore endian
// control chars
// reload
// review NSDocument
// check for leaks?
- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{	
	NSData* data = nil;
	NSTextStorage* storage = [_controller.view textStorage];
	NSMutableString* str = [storage mutableString];
	
	if ([typeName isEqualToString:@"Plain Text, UTF8 Encoded"])
	{
		data = [str dataUsingEncoding:self.encoding allowLossyConversion:YES];
	}
	else if ([typeName isEqualToString:@"Plain Text, UTF16 Encoded"])
	{
		// This case is only used when the user selects save as and then the utf16 encoding.
		self.encoding = NSUTF16LittleEndianStringEncoding;
		data = [str dataUsingEncoding:self.encoding allowLossyConversion:YES];
	}
	else if ([typeName isEqualToString:@"HTML"])
	{
		NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType};
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
		// There is also NSWordMLTextDocumentType, but that is an older (2003) XML format.
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

@end
