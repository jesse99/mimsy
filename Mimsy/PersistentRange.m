#import "PersistentRange.h"

#import "Assert.h"
#import "Logger.h"
#import "TextController.h"

@implementation PersistentRange
{
	NSString* _path;
	NSRange _onDiskRange;
	NSRange _inMemoryRange;
	RangeBlock _callback;
	
	__weak TextController* _controller;
}

- (id)init:(NSString*)path range:(NSRange)range block:(RangeBlock)callback
{
	ASSERT(path);
	ASSERT(range.location != NSNotFound);
	ASSERT(callback);
	
	self = [super init];
	if (self)
	{
		_path = path;
		_onDiskRange = range;
		_inMemoryRange = range;
		_callback = callback;
		LOG_DEBUG("PersistentRange", "ranges = %lu, %lu", _onDiskRange.location, _onDiskRange.length);

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
	LOG_DEBUG("PersistentRange", "closed window");
}

- (void)_windowSaved:(NSNotification*)notification
{
	UNUSED(notification);
	
	_onDiskRange = _inMemoryRange;
	LOG_DEBUG("PersistentRange", "onDisk = %lu, %lu (saved)", _onDiskRange.location, _onDiskRange.length);
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
			LOG_DEBUG("PersistentRange", "   editedRange = %lu, %lu", editedRange.location, editedRange.length);
			LOG_DEBUG("PersistentRange", "   self.range = %lu, %lu", self.range.location, self.range.length);

			_inMemoryRange.location = _inMemoryRange.location + changedLength;
			LOG_DEBUG("PersistentRange", "   inMemory = %lu, %lu", _inMemoryRange.location, _inMemoryRange.length);
			_callback(self);
		}
		else if (NSIntersectionRange(affectedRange, self.range).length > 0)
		{
			_inMemoryRange.location = NSNotFound;
			LOG_DEBUG("PersistentRange", "inMemory = %lu, %lu", _inMemoryRange.location, _inMemoryRange.length);
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
	[center removeObserver:self name:@"ReadingTextDocument" object:controller.document];
	[center removeObserver:self name:@"TextDocumentSaved" object:controller.document];
}

@end

