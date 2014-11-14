#import "PersistentRange.h"

#import "TextController.h"

@implementation PersistentRange
{
	NSString* _path;
	NSRange _onDiskRange;
	NSRange _inMemoryRange;
    NSUInteger _line;
    NSUInteger _col;
	RangeBlock _callback;
	
	__weak TextController* _controller;
}

- (id)init:(NSString*)path range:(NSRange)range block:(RangeBlock)callback
{
	ASSERT(path);
	ASSERT(range.location != NSNotFound);
	
	self = [super init];
	if (self)
	{
		_path = path;
		_onDiskRange = range;
		_inMemoryRange = range;
		_callback = callback;
		LOG("Text:PersistentRange:Verbose", "ranges = %lu, %lu", _onDiskRange.location, _onDiskRange.length);

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowOpened:) name:@"TextWindowOpened" object:nil];
		
		TextController* controller = [TextController find:path];
		if (controller)
		{
			[self _registerNotifications:controller];
			_controller = controller;
		}
	}
	
	return self;
}

- (id)init:(NSString*)path line:(NSUInteger)line col:(NSUInteger)col block:(RangeBlock)callback
{
    ASSERT(path);
    
    self = [super init];
    if (self)
    {
        _path = path;
        _onDiskRange = NSMakeRange(NSNotFound, 0);
        _inMemoryRange = NSMakeRange(NSNotFound, 0);
        _line = line;
        _col = col;
        _callback = callback;
        LOG("Text:PersistentRange:Verbose", "line:col = %lu, %lu", _line, _col);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowOpened:) name:@"TextWindowOpened" object:nil];
        
        TextController* controller = [TextController find:path];
        if (controller)
        {
            [self _registerNotifications:controller];
            _controller = controller;
        }
    }
    
    return self;
}

- (void)dealloc
{
	TextController* controller = _controller;
	if (controller)
	{
		[self _deregisterNotifications:controller];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"TextWindowOpened" object:nil];
	}
}

- (NSRange)range
{
	TextController* controller = _controller;
	if (controller)
		return _inMemoryRange;
	else
		return _onDiskRange;
}

// TODO: reset _line and _col after deleting them
- (void)_windowOpened:(NSNotification*)notification
{
	TextController* controller = notification.object;
	if ([_path compare:controller.path] == NSOrderedSame)
	{
		[self _registerNotifications:controller];
		_controller = controller;
	}
}

- (void)_windowClosing:(NSNotification*)notification
{
	TextController* controller = notification.object;
	[self _deregisterNotifications:controller];
	
	_controller = nil;
	LOG("Text:PersistentRange", "closed window");
}

- (void)_windowSaved:(NSNotification*)notification
{
	UNUSED(notification);
	
	_onDiskRange = _inMemoryRange;
	LOG("Text:PersistentRange", "onDisk = %lu, %lu (saved)", _onDiskRange.location, _onDiskRange.length);
}

// TODO: We do not handle reverting changes properly. Not sure how to
// do that when Cocoa auto-saves documents at the drop of a hat. We'd
// have to somehow figure out that an auto-saved document was not
// actually saved (and we can't seem to use the URL to figure that
// out).
- (void)_windowEdited:(NSNotification*)notification
{
	if (_inMemoryRange.location != NSNotFound)
	{
		TextController* controller = notification.object;
		NSTextStorage* storage = controller.getTextView.textStorage;
		
		NSRange editedRange = storage.editedRange;
		NSUInteger changedLength = (NSUInteger) storage.changeInLength;
		NSRange affectedRange = NSMakeRange(editedRange.location, editedRange.length - changedLength);

		if (affectedRange.location + affectedRange.length < self.range.location)
		{
			LOG("Text:PersistentRange", "   editedRange = %lu, %lu", editedRange.location, editedRange.length);
			LOG("Text:PersistentRange", "   self.range = %lu, %lu", self.range.location, self.range.length);

			_inMemoryRange.location = _inMemoryRange.location + changedLength;
			LOG("Text:PersistentRange", "   inMemory = %lu, %lu", _inMemoryRange.location, _inMemoryRange.length);
            if (_callback)
                _callback(self);
		}
		else if (NSIntersectionRange(affectedRange, self.range).length > 0)
		{
			_inMemoryRange.location = NSNotFound;
			LOG("Text:PersistentRange", "inMemory = %lu, %lu", _inMemoryRange.location, _inMemoryRange.length);
            if (_callback)
                _callback(self);
		}
	}
}

- (void)_registerNotifications:(TextController*)controller
{
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	
	[center addObserver:self selector:@selector(_windowClosing:) name:@"TextWindowClosing" object:controller];
	[center addObserver:self selector:@selector(_windowEdited:) name:@"TextWindowEdited" object:controller];
	[center addObserver:self selector:@selector(_windowSaved:) name:@"TextDocumentSaved" object:controller.document];
}

- (void)_deregisterNotifications:(TextController*)controller
{
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	
	[center removeObserver:self name:@"TextWindowClosing" object:controller];
	[center removeObserver:self name:@"TextWindowEdited" object:controller];
	[center removeObserver:self name:@"TextDocumentSaved" object:controller.document];
}

@end

