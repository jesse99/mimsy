#import "WarningWindow.h"

#import "AppDelegate.h"
#import "Logger.h"

const int MinAlpha = 20;

@implementation WarningWindow
{
	NSWindow* _window;
	bool _opening;
	int _alpha;
	unsigned int _delay;
	NSString* _text;
	NSMutableDictionary* _attrs;
	
	NSBezierPath* _background;
	NSColor* _color;
}

static NSSize getTextSize(NSString* text, NSDictionary* attrs)
{
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:text attributes:attrs];
	return str.size;
}

- (id)init
{
	self = [super init];
	
	if (self)
	{
		// Interface Builder won't allow us to create a window with no title bar
		// so we have to create it manually. But we could use IB if we display
		// the window with a sheet...
		NSRect rect = NSMakeRect(0, 0, 460, 105);
		_window = [[NSWindow alloc] initWithContentRect:rect styleMask:0 backing:NSBackingStoreBuffered defer:false];
		[_window setHasShadow:false];
		
		// Initialize the text attributes.
		_attrs = [NSMutableDictionary new];
		
		NSFont* font = [NSFont fontWithName:@"Georgia" size:64.0f];
		_attrs[NSFontAttributeName] = font;
		
		NSMutableParagraphStyle* style = [NSMutableParagraphStyle new];
		[style setAlignment:NSCenterTextAlignment];
		_attrs[NSParagraphStyleAttributeName] = style;
		
		_color = [NSColor colorWithDeviceRed:250/255.0f green:128/255.0f blue:114/255.0f alpha:1.0f];
	}
	
	return self;
}

- (void)show:(NSWindow*)parent withText:(NSString*)text red:(int)r green:(int)g blue:(int)b
{
	_color = [NSColor colorWithDeviceRed:r/255.0f green:g/255.0f blue:b/255.0f alpha:1.0f];
	_text = text;

    AppDelegate* app = [NSApp delegate];
    _delay = [app.layeredSettings uintValue:@"WarnWindowDelay" missing:60];
		
	[self _resize:text];
	
	NSRect pframe = parent.frame;
	NSRect cframe = _window.frame;
	NSPoint center = NSMakePoint(pframe.origin.x + pframe.size.width/2.0f, pframe.origin.y + pframe.size.height/2.0f);
	[_window setFrameTopLeftPoint:NSMakePoint(center.x - cframe.size.width/2, center.y + cframe.size.height/2)];
	
	_opening = true;
	_alpha = MinAlpha;
	
	[self _animate];
}

- (void)_resize:(NSString*)text
{
	NSSize size = getTextSize(text, _attrs);
	[_window setFrame:NSMakeRect(0, 0, 1.2*size.width, size.height) display:FALSE];

	// Initialize the background bezier.
	_background = [NSBezierPath new];
	NSView* view = _window.contentView;
	[_background appendBezierPathWithRoundedRect:view.bounds xRadius:20.0f yRadius:20.0f];
}

- (void)_animate
{
	if (_opening)
	{
		[_window orderFront:nil];		// if we don't always do this the find reached start window goes away too fast...
		
		_alpha += 10;
		if (_alpha == 100)
			_opening = false;
	}
	else
	{
		_alpha -= 10;
		if (_alpha == MinAlpha)
			[_window orderOut:nil];
	}
	
	if (_alpha >= MinAlpha)
	{
		[self _draw];
		
		dispatch_queue_t main = dispatch_get_main_queue();
		dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, _delay*NSEC_PER_MSEC);
		dispatch_after(delay, main, ^{[self _animate];});
	}
}

- (void)_draw
{
	[_window setAlphaValue:_alpha/100.0f];
	
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithWindow:_window];
	[NSGraphicsContext setCurrentContext:context];
	
	NSView* view = _window.contentView;
	NSRect bounds = view.bounds;
	
	// draw the background
	[_color setFill];
	[_background fill];
	
	// draw the text
	[_text drawInRect:bounds withAttributes:_attrs];
	
	[context flushGraphics];
	[NSGraphicsContext restoreGraphicsState];
}

@end
