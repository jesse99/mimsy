#import "TranscriptController.h"
#import "Logger.h"

static TranscriptController* controller;

// TODO: Need to do a lot here, e.g. styling and possibly thread safety.
@implementation TranscriptController

- (id)init
{
	self = [super initWithWindowNibName:@"Transcript"];
	if (self)
	{
		[self showWindow:self];
	}
    
    return self;
}


- (void)windowDidLoad
{
    [super windowDidLoad];
}

+ (TranscriptController*)getInstance
{
	if (controller == nil)
		controller = [TranscriptController new];
	
	return controller;
}

+ (void)writeCommand:(NSString*)text
{
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:text];
	[[[TranscriptController getInstance].view textStorage] appendAttributedString:str];
}

+ (void)writeStderr:(NSString*)text
{
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:text];
	[[[TranscriptController getInstance].view textStorage] appendAttributedString:str];
}

+ (void)writeStdout:(NSString*)text
{
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:text];
	[[[TranscriptController getInstance].view textStorage] appendAttributedString:str];
}

+ (void)writeError:(NSString*)text
{
	ERROR("Mimsy", "%@", text);
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"]];
	[[[TranscriptController getInstance].view textStorage] appendAttributedString:str];
}

@end
