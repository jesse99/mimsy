#import "Styler.h"

@implementation Styler

+ (void)computeStylesFor:(NSString*)language withText:(NSString*)text editCount:(NSUInteger)count completion:(StylesCompleted)callback
{
	(void) language;
	(void) text;
	(void) count;
	(void) callback;
	
	// dispatch_queue_t aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	// call completion on the main thread
	
	// We're processing the text using a task so we need to ensure that
	// no one is changing the text as we process it. Note that in the
	// unlikely case where the string is actually immutable this will
	// be efficient.
	//NSString* text = [text copy];
}

@end






