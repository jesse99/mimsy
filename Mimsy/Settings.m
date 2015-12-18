#import "Settings.h"

#import "AppDelegate.h"
#import "DirectoryController.h"
#import "Plugins.h"
#import "TextController.h"
#import "TranscriptController.h"

static bool _inited;
static NSWindow* _mainWindow;
id<SettingsContext> activeContext;

@implementation Settings
{
    id<SettingsContext> _context;
    NSString* _fileName;
    NSMutableArray* _keys;
    NSMutableArray* _values;
    NSMutableArray* _dupes;
    NSUInteger _hash;
}

- (Settings*)init:(NSString*)name context:(id<SettingsContext>)context
{
    ASSERT(name != nil);
    ASSERT(context != nil);
    
    _fileName = name;
    _context = context;
    
    _keys   = [NSMutableArray new];
    _values = [NSMutableArray new];
    _dupes  = [NSMutableArray new];
    
    if (!_inited)
    {
        [Settings registerNotifications];
        _inited = true;
    }
    
    return self;
}

+ (void)registerNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowOrderChanged:) name:NSWindowDidBecomeMainNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowOrderChanged:) name:
     NSWindowDidResignMainNotification object:nil];
}

+ (void)windowOrderChanged:(NSNotification*)notification
{
    UNUSED(notification);
    
    // Become main and resign main are normally paired so we'll defer tbhe enumeration to
    // avoid doing it twice.
    [AppDelegate execute:@"update settings context" deferBy:0.2 withBlock:^{
        id<SettingsContext> oldContext = activeContext;

        activeContext = [NSApp delegate];
        for (NSWindow* window in [NSApp orderedWindows])
        {
            if (window.isVisible && window.windowController)
                if ([window.windowController isKindOfClass:[TextController class]])
                {
                    activeContext = window.windowController;
                    break;
                }
                else if ([window.windowController isKindOfClass:[DirectoryController class]])
                {
                    activeContext = window.windowController;
                    break;
                }
        }
        
        if (oldContext != activeContext)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsChanged" object:self];
            [Plugins refreshSettings];
        }
        
        NSWindow* window = [NSApp mainWindow];
        if (window != _mainWindow)
        {
            [Plugins mainChanged:window.windowController];
            _mainWindow = window;
        }
    }];
}


- (id<SettingsContext>)context
{
    return _context;
}

- (void)addKey:(NSString*)key value:(NSString*)value
{
    ASSERT(key != nil);
    ASSERT(value != nil);
    
    [_keys addObject:key];
    [_values addObject:value];
    _hash += key.hash + value.hash;
}

- (bool)hasKey:(NSString*)name
{
    NSString* value = [self _findValueForKey:name missing:nil];
    return value != nil;
}

- (NSArray*)getKeys
{
    return [self _findKeys];
}

- (BOOL)boolValue:(NSString*)name missing:(BOOL)value
{
    NSString* str = [self _findValueForKey:name missing:nil];
    
    if (str)
        return [str compare:@"true"] == NSOrderedSame;
    else
        return value;
}

- (int)intValue:(NSString*)name missing:(int)value
{
    NSString* str = [self _findValueForKey:name missing:nil];
    
    if (str)
    {
        int result = [str intValue];
        if (result != 0)
        {
            return result;
        }
        else
        {
            if ([str compare:@"0"] == NSOrderedSame)
            {
                return 0;
            }
            else
            {
                NSString* mesg = [NSString stringWithFormat:@"Setting %@'s value is '%@' which is not a valid integer.", name, str];
                [TranscriptController writeError:mesg];
                
                return value;
            }
        }
    }
    else
    {
        return value;
    }
}

- (float)floatValue:(NSString *)name missing:(float)value
{
    NSString* str = [self _findValueForKey:name missing:nil];
    
    if (str)
    {
        float result = [str floatValue];
        if (result != 0)
        {
            return result;
        }
        else
        {
            if ([str compare:@"0"] == NSOrderedSame || [str compare:@"0.0"] == NSOrderedSame)
            {
                return 0;
            }
            else
            {
                NSString* mesg = [NSString stringWithFormat:@"Setting %@'s value is '%@' which is not a valid float.", name, str];
                [TranscriptController writeError:mesg];
                
                return value;
            }
        }
    }
    else
    {
        return value;
    }
}

- (unsigned int)uintValue:(NSString*)name missing:(unsigned int)value
{
    NSString* str = [self _findValueForKey:name missing:nil];
    
    if (str)
    {
        int result = [str intValue];
        if (result > 0)
        {
            return (unsigned int) result;
        }
        else
        {
            if ([str compare:@"0"] == NSOrderedSame)
            {
                return 0;
            }
            else
            {
                NSString* mesg = [NSString stringWithFormat:@"Setting %@'s value is '%@' which is not a valid unsigned integer.", name, str];
                [TranscriptController writeError:mesg];
                
                return value;
            }
        }
    }
    else
    {
        return value;
    }
}

- (NSString*)stringValue:(NSString*)name missing:(NSString*)value
{
    return [self _findValueForKey:name missing:value];
}

- (NSArray*)stringValues:(NSString*)name
{
    return [self _findValuesForKey:name];
}

- (void)enumerate:(NSString*) key with:(void (^)(NSString* fileName, NSString* value))block
{
    Settings* settings = self;
    
    while (settings)
    {
        [settings _enumerateOne:key with:block];
        settings = settings.context.parent.settings;
    }
}

- (NSUInteger)checksum
{
    NSUInteger hash = 0;
    Settings* settings = self;
    
    while (settings)
    {
        hash += settings->_hash;
        settings = settings.context.parent.settings;
    }
    
    return hash;
}

- (NSString*)_findValueForKey:(NSString*)key missing:(NSString*)missing
{
    Settings* settings = self;
    
    while (settings)
    {
        NSString* candidate = [settings _findValueForKeyOne:key];
        if (candidate)
            return candidate;
        settings = settings.context.parent.settings;
    }
    
    return missing;
}

- (NSArray*)_findValuesForKey:(NSString*)key
{
    NSMutableArray* values = [NSMutableArray new];
    Settings* settings = self;
    
    while (settings)
    {
        [settings _addValuesForKeyOne:key values:values];
        settings = settings.context.parent.settings;
    }
    
    return values;
}

- (NSArray*)_findKeys
{
    NSMutableArray* keys = [NSMutableArray new];
    Settings* settings = self;
    
    while (settings)
    {
        [settings _addKeysOne:keys];
        settings = settings.context.parent.settings;
    }
    
    return keys;
}

// It'd be nicer to use something like a multimap here but there should
// be few enough entries that a linear algorithm should be fine.
- (NSString*)_findValueForKeyOne:(NSString*)key
{
    ASSERT(key != nil);
    NSString* result = nil;
    
    for (NSUInteger i = 0; i < _keys.count; ++i)
    {
        NSString* candidate = _keys[i];
        if ([candidate compare:key] == NSOrderedSame)
        {
            if (!result)
            {
                result = _values[i];
            }
            else if ([_dupes indexOfObject:key] == NSNotFound)
            {
                // This can get annoying so we won't warn every time.
                NSString* mesg = [NSString stringWithFormat:@"%@ has multiple %@ settings", _fileName, key];
                [TranscriptController writeError:mesg];
                [_dupes addObject:key];
            }
        }
    }
    
    return result;	
}

- (void)_addValuesForKeyOne:(NSString*)key values:(NSMutableArray*)values
{
    ASSERT(key != nil);
    
    for (NSUInteger i = 0; i < _keys.count; ++i)
    {
        NSString* candidate = _keys[i];
        if ([candidate compare:key] == NSOrderedSame)
        {
            NSObject* value =_values[i];
            [values addObject:value];
        }
    }
}

- (void)_addKeysOne:(NSMutableArray*)values
{
    for (NSUInteger i = 0; i < _keys.count; ++i)
    {
        NSString* key = _keys[i];
        [values addObject:key];
    }
}

- (void)_enumerateOne:(NSString*) key with:(void (^)(NSString* fileName, NSString* value))block
{
    for (NSUInteger i = 0; i < _keys.count; ++i)
    {
        NSString* candidate = _keys[i];
        if ([candidate compare:key] == NSOrderedSame)
        {
            block(_fileName, _values[i]);
        }
    }
}

@end
