#import "SpecialKeys.h"

#import "AppDelegate.h"
#import "Paths.h"
#import "TranscriptController.h"

static NSDictionary* _keyNameAttrs;
static NSDictionary* _keyTextAttrs;
static NSDictionary* _keySrcAttrs;

static NSDictionary* _json;

@implementation SpecialKeys

+ (void)setup
{
	[SpecialKeys _loadDefaults];
	if (!_json)
		return;
			
	[SpecialKeys _writeFiles:_json[@"contexts"] footers:_json[@"footers"]];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_loadingExtensions:) name:@"LoadingExtensions" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_loadedExtensions:) name:@"LoadedExtensions" object:nil];
}

+ (void)_loadingExtensions:(NSNotification*)notification
{
	UNUSED(notification);
	[SpecialKeys _loadDefaults];
}

+ (void)addPlugin:(NSString*)plugin context:(NSString*)context key:(NSString*)name description:(NSString*)description
{
    NSMutableDictionary* contexts = _json[@"contexts"];
    
    NSMutableDictionary* keys = contexts[context];
    if (!keys)
    {
        keys = [NSMutableDictionary new];
        contexts[context] = keys;
    }
    
    keys[name] = description;
    keys[[name stringByAppendingString:@"-extension"]] = plugin;
}

+ (void)removePlugin:(NSString*)plugin context:(NSString*)context
{
    NSMutableDictionary* contexts = _json[@"contexts"];
    
    NSMutableDictionary* keys = contexts[context];
    if (keys)
    {
        NSMutableArray* zombies = [NSMutableArray new];
        for (NSString* extName in keys)
        {
            NSString* value = keys[extName];
            if ([value isEqualToString:plugin])
            {
                [zombies addObject:extName];
                
                NSString* name = [extName stringByReplacingOccurrencesOfString:@"-extension" withString:@""];
                [zombies addObject:name];
            }
        }
        
        for (NSString* name in zombies)
        {
            [keys removeObjectForKey:name];
        }
    }
}

+ (void)updated
{
    [SpecialKeys _writeFiles:_json[@"contexts"] footers:_json[@"footers"]];
}

// {
// 	"extension": "option-tab",
// 	"context": "text editor",
// 	"keys":
// 	{
// 		"Command-Option-Tab": "Select the next identifier",
// 		"Command-Shift-Option-Tab": "Select the previous identifier"
// 	}
// }
+ (void)_addExtensionData:(NSString*)text
{
	NSError* error = nil;
	NSData* data = [text dataUsingEncoding:NSUTF8StringEncoding];
	id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
	if (!json)
	{
		NSString* reason = error.localizedFailureReason;
		[TranscriptController writeError:[NSString stringWithFormat:@"Couldn't parse the extension's json: %@", reason]];
		[TranscriptController writeStdout:text];
		return;
	}
    
    for (NSString* name in json[@"keys"])
	{
        [SpecialKeys addPlugin:json[@"extension"] context:json[@"context"] key:name description:json[@"keys"][name]];
	}
}

+ (void)_loadedExtensions:(NSNotification*)notification
{
	UNUSED(notification);
	[SpecialKeys _writeFiles:_json[@"contexts"] footers:_json[@"footers"]];
}

+ (void)_loadDefaults
{
	_json = [SpecialKeys _loadBuiltIns];
	if (!_json)
		return;
	
	_keyNameAttrs = [SpecialKeys _createAttributes:_json name:@"key-name"];
	_keyTextAttrs = [SpecialKeys _createAttributes:_json name:@"key-text"];
    _keySrcAttrs = [SpecialKeys _createAttributes:_json name:@"key-src"];
}

+ (void)_writeFiles:(NSDictionary*)contexts footers:(NSDictionary*)footers
{
	MimsyPath* dir = [Paths installedDir:@"help"];

	for (NSString* context in contexts)
	{
		NSDictionary* keys = contexts[context];
		
		NSAttributedString* text = [SpecialKeys _createText:keys footer:footers[context]];
		if (!text)
			return;
		
		NSArray* parts = [context componentsSeparatedByString:@" "];
		parts = [parts map:^id(NSString* element) {return [element titleCase];}];
		NSString* name = [NSString stringWithFormat:@"%@-%@ Keys.rtf", context, [parts componentsJoinedByString:@" "]];
		MimsyPath* fname = [dir appendWithComponent:name];
		NSURL* url = fname.asURL;
		
		NSError* error = nil;
		NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType};
		NSFileWrapper* wrapper = [text fileWrapperFromRange:NSMakeRange(0, text.length) documentAttributes:attrs error:&error];
		if (!wrapper)
		{
			NSString* reason = error.localizedFailureReason;
			[TranscriptController writeError:[NSString stringWithFormat:@"Couldn't serialize %@: %@", fname, reason]];
			return;
		}
		
		[wrapper writeToURL:url options:NSFileWrapperWritingAtomic originalContentsURL:nil error:&error];
		if (!wrapper)
		{
			NSString* reason = error.localizedFailureReason;
			[TranscriptController writeError:[NSString stringWithFormat:@"Couldn't write %@: %@", fname, reason]];
			return;
		}
	}
}

+ (NSDictionary*)_createAttributes:(NSDictionary*)json name:(NSString*)name
{
	NSMutableDictionary* attrs = [NSMutableDictionary new];
	
	NSDictionary* fonts = json[@"fonts"];
	NSArray* params = fonts[name];
	
	NSNumber* size = params[1];
	NSFont* font = [NSFont fontWithName:params[0] size:size.floatValue];
	attrs[NSFontAttributeName] = font;
	
	return attrs;
}

+ (NSAttributedString*)_createText:(NSDictionary*)keys footer:(NSString*)footer
{
	NSMutableAttributedString* text = [NSMutableAttributedString new];
	
	for (NSString* name in [keys.allKeys sortedArrayUsingSelector:@selector(compare:)])
	{
        if (![name hasSuffix:@"-extension"])
        {
            [SpecialKeys _appendText:text attrs:_keyNameAttrs contents:name];
            [SpecialKeys _appendText:text attrs:_keyNameAttrs contents:@"\t\t"];
            
            [SpecialKeys _appendText:text attrs:_keyTextAttrs contents:keys[name]];
            
            NSString* extension = keys[[name stringByAppendingString:@"-extension"]];
            if (extension)
            {
                [SpecialKeys _appendText:text attrs:_keyNameAttrs contents:@" "];
                [SpecialKeys _appendText:text attrs:_keySrcAttrs contents:extension];
            }

            [SpecialKeys _appendText:text attrs:_keyTextAttrs contents:@"\n"];
        }
    }
	
	if (footer && footer.length > 0)
	{
		[SpecialKeys _appendText:text attrs:_keyTextAttrs contents:@"\n"];
		[SpecialKeys _appendText:text attrs:_keyTextAttrs contents:footer];
	}
	
	return text;
}

+ (void)_appendText:(NSMutableAttributedString*)text attrs:(NSDictionary*)attrs contents:(NSString*)contents
{
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:contents attributes:attrs];
	[text appendAttributedString:str];
}

+ (id)_loadBuiltIns
{
	MimsyPath* dir = [Paths installedDir:@"help"];
	MimsyPath* fname = [dir appendWithComponent:@"built-in-special-keys.json"];
	
	NSError* error = nil;
	NSString* text = [NSString stringWithContentsOfFile:fname.asString encoding:NSUTF8StringEncoding error:&error];
	if (!text)
	{
		NSString* reason = error.localizedFailureReason;
		[TranscriptController writeError:[NSString stringWithFormat:@"Couldn't read %@: %@", fname, reason]];
		return nil;
	}
	
	NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*\\#.*$" options:NSRegularExpressionAnchorsMatchLines error:&error];
	ASSERT(regex);
	text = [regex stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
	
	NSData* data = [text dataUsingEncoding:NSUTF8StringEncoding];
	id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
	if (!json)
	{
		NSString* reason = error.localizedFailureReason;
		[TranscriptController writeError:[NSString stringWithFormat:@"Couldn't parse %@: %@", fname, reason]];
		return nil;
	}
	
	return json;
}

@end
