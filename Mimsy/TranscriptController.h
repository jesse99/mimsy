#import <Cocoa/Cocoa.h>

#import "BaseTextController.h"

// Manages access to the window used to display the results of builds
// (and the occasional message from Mimsy).
@interface TranscriptController : BaseTextController

@property IBOutlet NSTextView* view;

+ (bool)empty;

+ (void)writeCommand:(NSString*)text;	// typically the text of a command executed via a build tool
+ (void)writeStderr:(NSString*)text;	// typically stderr from a tool run via a build
+ (void)writeStdout:(NSString*)text;	// typically stdout from a tool run via a build

+ (void)writeError:(NSString*)text;		// Mimsy error (unlike the others this appends a new-line)

- (NSTextView*)getTextView;
- (NSUInteger)getEditCount;

@end
