#import "AsyncStyler.h"

#import "Language.h"
#import "RegexStyler.h"

@implementation AsyncStyler

+ (void)computeStylesFor:(Language*)lang withText:(NSString*)text editCount:(NSUInteger)count completion:(StylesCompleted)callback
{
	// We're processing the text using a task so we need to ensure that
	// no one is changing the text as we process it. Note that in the
	// unlikely case where the string is actually immutable this will
	// be efficient.
	text = [text copy];

	dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_queue_t main = dispatch_get_main_queue();	
	dispatch_async(concurrent,
		^{
			StyleRuns* runs = [lang.styler computeStyles:text editCount:count];
			dispatch_async(main, ^{callback(runs);});
		});
}

@end







