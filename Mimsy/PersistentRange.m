#import "PersistentRange.h"

#import "TextController.h"
#import "TranscriptController.h"

@implementation PersistentRange
{
	MimsyPath* _path;
	NSRange _onDiskRange;
	NSRange _inMemoryRange;
    NSUInteger _line;
    NSUInteger _col;
	RangeBlock _callback;
	
	__weak BaseTextController* _controller;
}

// We take a TranscriptController instead of a BaseTextController because we don't want to use this method
// for normal text documents (because we need the path when those are re-opened).
- (id)init:(TranscriptController*)controller range:(NSRange)range
{
    ASSERT(controller);
    ASSERT(range.location != NSNotFound);
    
    self = [super init];
    if (self)
    {
        _path = nil;
        _onDiskRange = range;
        _inMemoryRange = range;
        _callback = nil;
        LOG("Text:PersistentRange:Verbose", "ranges = %lu, %lu", _onDiskRange.location, _onDiskRange.length);
        
        [self _registerNotifications:controller];
        _controller = controller;
    }
    
    return self;
}

- (id)init:(MimsyPath*)path range:(NSRange)range block:(RangeBlock)callback
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
		
		BaseTextController* controller = [TextController find:path];
		if (controller)
		{
			[self _registerNotifications:controller];
			_controller = controller;
		}
	}
	
	return self;
}

- (id)init:(MimsyPath*)path line:(NSUInteger)line col:(NSUInteger)col block:(RangeBlock)callback
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
        
        BaseTextController* controller = [TextController find:path];
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
	BaseTextController* controller = _controller;
	if (controller)
	{
		[self _deregisterNotifications:controller];
        
        if (_path)
            [[NSNotificationCenter defaultCenter] removeObserver:self name:@"TextWindowOpened" object:nil];
	}
}

- (NSRange)range
{
	BaseTextController* controller = _controller;
	if (controller)
		return _inMemoryRange;
	else
		return _onDiskRange;
}

// TODO: reset _line and _col after deleting them
- (void)_windowOpened:(NSNotification*)notification
{
    ASSERT(_path);

    TextController* controller = notification.object;
    if ([_path isEqualToPath:controller.path])
    {
        [self _registerNotifications:controller];
        _controller = controller;
    }
}

- (void)_windowClosing:(NSNotification*)notification
{
	BaseTextController* controller = notification.object;
	[self _deregisterNotifications:controller];
	
	_controller = nil;
	LOG("Text:PersistentRange:Verbose", "closed window");
}

- (void)_windowSaved:(NSNotification*)notification
{
	UNUSED(notification);
	
	_onDiskRange = _inMemoryRange;
	LOG("Text:PersistentRange:Verbose", "onDisk = %lu, %lu (saved)", _onDiskRange.location, _onDiskRange.length);
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
		BaseTextController* controller = notification.object;
		NSTextStorage* storage = controller.getTextView.textStorage;
		
		NSRange editedRange = storage.editedRange;
		NSUInteger changedLength = (NSUInteger) storage.changeInLength;
		NSRange affectedRange = NSMakeRange(editedRange.location, editedRange.length - changedLength);

		if (affectedRange.location + affectedRange.length < self.range.location)
		{
			LOG("Text:PersistentRange:Verbose", "   editedRange = %lu, %lu", editedRange.location, editedRange.length);
			LOG("Text:PersistentRange:Verbose", "   self.range = %lu, %lu", self.range.location, self.range.length);

			_inMemoryRange.location = _inMemoryRange.location + changedLength;
			LOG("Text:PersistentRange:Verbose", "   inMemory = %lu, %lu", _inMemoryRange.location, _inMemoryRange.length);
            if (_callback)
                _callback(self);
		}
		else if (NSIntersectionRange(affectedRange, self.range).length > 0)
		{
			_inMemoryRange.location = NSNotFound;
			LOG("Text:PersistentRange:Verbose", "inMemory = %lu, %lu", _inMemoryRange.location, _inMemoryRange.length);
            if (_callback)
                _callback(self);
		}
	}
}

- (void)_registerNotifications:(BaseTextController*)controller
{
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	
	[center addObserver:self selector:@selector(_windowEdited:) name:@"TextWindowEdited" object:controller];
    
    if (_path)
    {
        [center addObserver:self selector:@selector(_windowClosing:) name:@"TextWindowClosing" object:controller];
        [center addObserver:self selector:@selector(_windowSaved:) name:@"TextDocumentSaved" object:controller.document];
    }
}

- (void)_deregisterNotifications:(BaseTextController*)controller
{
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	
	[center removeObserver:self name:@"TextWindowEdited" object:controller];

    if (_path)
    {
        [center removeObserver:self name:@"TextWindowClosing" object:controller];
        [center removeObserver:self name:@"TextDocumentSaved" object:controller.document];
    }
}

@end

