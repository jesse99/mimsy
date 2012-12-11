#import "TextDocument.h"

#import "TextController.h"

@implementation TextDocument
{
	TextController* controller;
	NSMutableAttributedString* text;
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
	controller = [[TextController alloc] init];
	[self addWindowController:controller];
}

- (void)controllerDidLoad
{
	NSAssert([controller view], @"%@ has a nil view", controller);

	if (text)
	{
		[[[controller view] textStorage] setAttributedString:text];
		text = nil;
	}
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

// TODO:
// encoding
// bad encoding
// endian
// gremlins
// rich formats
// confirm on large files
// reload
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	(void) typeName;
	(void) outError;
	
	NSAssert(text == nil, @"%@ should be nil", text);
	
	NSStringEncoding encoding = NSUTF8StringEncoding;
	NSString* str = [[NSString alloc] initWithData:data encoding:encoding];
	text = [[NSMutableAttributedString alloc] initWithString:str];
	
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
