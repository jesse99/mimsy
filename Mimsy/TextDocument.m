#import "TextDocument.h"

#import "TextController.h"

@implementation TextDocument
{
	TextController* _controller;
	NSMutableAttributedString* _text;
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

	if (_text)
	{
		[[[_controller view] textStorage] setAttributedString:_text];
		_text = nil;
	}
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

// TODO:
// encoding
// bad encoding (eg a binary file)
// check for leaks, use profile action
// maybe use a better name for the controller view outlet (be sure to commit 1st)
// endian
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
	(void) outError;
	
	NSAssert(_text == nil, @"%@ should be nil", _text);
	
	NSStringEncoding encoding = NSUTF8StringEncoding;
	NSString* str = [[NSString alloc] initWithData:data encoding:encoding];
	_text = [[NSMutableAttributedString alloc] initWithString:str];
	
	// Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
	// You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
	// If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
	return YES;
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
