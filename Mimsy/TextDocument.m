#import "TextDocument.h"

#import "Decode.h"
#import "TextController.h"

static enum LineEndian getEndian(NSString* text, bool* hasMac, bool* hasWindows)
{
	int counts[3] = {0};
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

// TODO:
// line endian
// saving
// revert (make sure the order of operations is ok)
// gremlins
// make sure arbitrary files can be read
// rich formats
// binary format
// confirm on large files
// reload
// review NSDocument
// check for leaks
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	(void) typeName;
	
	NSAssert(self.text == nil, @"%@ should be nil", self.text);
	
	Decode* decode = [[Decode alloc] initWithData:data];
	NSMutableString* text = [decode text];
	if (text)
	{
		bool hasMac, hasWindows;
		self.endian = getEndian(text, &hasMac, &hasWindows);
		
		// To make life easier on ourselves text documents in memory are always
		// unix endian (this will also fixup files with mixed line endings).
		if (hasWindows)
			[text replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, [text length])];
		
		if (hasMac)
			[text replaceOccurrencesOfString:@"\r" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, [text length])];
		
		self.text = [[NSMutableAttributedString alloc] initWithString:text];
		return YES;
	}
	else
	{
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:[decode error]};
		*outError = [NSError errorWithDomain:@"mimsy" code:1 userInfo:dict];
		return NO;
	}
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	(void) typeName;
	(void) outError;
	
	// Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
	// You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
	NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
	@throw exception;
	return nil;
}

@end
