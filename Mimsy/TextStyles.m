#import "TextStyles.h"

#import "ConfigParser.h"
#import "Metadata.h"
#import "Paths.h"
#import "TranscriptController.h"
#import "Utils.h"

static NSDictionary* _baseAttrs;

@implementation TextStyles
{
	NSString* _path;					// path to the styles file
	NSMutableDictionary* _attrMap;		// element name => attributes
	NSColor* _backColor;
	NSDictionary* _values;
}

- (id)initWithPath:(NSString*)path expectBackColor:(bool)expectBackColor
{
	if (_baseAttrs == nil)
	{
		// This should include everything which might be applied from a style run.
		NSMutableDictionary* attrs = [NSMutableDictionary new];
		attrs[NSFontAttributeName]               = [NSFont fontWithName:@"Times" size:17];	// TODO: use a pref for this
		attrs[NSForegroundColorAttributeName]    = [NSColor blackColor];
		attrs[NSUnderlineStyleAttributeName]     = @0;
		attrs[NSLigatureAttributeName]           = @1;
		attrs[NSBaselineOffsetAttributeName]     = @0.0;
		attrs[NSStrokeWidthAttributeName]        = @0;
		attrs[NSStrikethroughStyleAttributeName] = @0;
		attrs[NSObliquenessAttributeName]        = @0;
		attrs[NSExpansionAttributeName]          = @0.0;
		attrs[@"element name"]                   = @"base";
		_baseAttrs = attrs;
	}
	
	_path = path;
	LOG("Text:Styler:Verbose", "Loading styles from %s", STR(_path));
	
	NSMutableDictionary* map = [NSMutableDictionary new];
	NSAttributedString* text = [self _loadStyles];
	if (!text || ![self _parseStyles:text attrMap:map path:path])
		map[@"normal"] = _baseAttrs;
	_attrMap = map;
	
	NSError* error = nil;
	NSColor* color = [Metadata readCriticalDataFrom:_path named:@"back-color" outError:&error];
	if (color)
	{
		_backColor = color;
	}
	else
	{
		_backColor = [NSColor whiteColor];
		
		if (expectBackColor)
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Couldn't read back-color from '%@':\n%@.", _path, reason];
			[TranscriptController writeError:mesg];
		}
	}
	
	return self;
}

- (NSDictionary*)attributesForElement:(NSString*)name
{
	NSDictionary* result = _attrMap[name];
	if (!result)
	{
		LOG("Warning", "Couldn't find element %s in the styles file", STR(name));
		result = _attrMap[@"normal"];
		_attrMap[name] = result;
	}
	
	return result;
}

- (NSDictionary*)attributesForOnlyElement:(NSString*)name
{
	NSDictionary* result = _attrMap[name];
	return result;
}

- (NSColor*)backColor
{
	return _backColor;
}

- (NSString*)valueForKey:(NSString*)key
{
	return _values[key];
}

- (NSAttributedString*)_loadStyles
{
	NSURL* url = [NSURL fileURLWithPath:_path];
	
	NSError* error = nil;
	NSUInteger options = NSFileWrapperReadingImmediate | NSFileWrapperReadingWithoutMapping;
	NSFileWrapper* file = [[NSFileWrapper alloc] initWithURL:url options:options error:&error];
	if (file)
	{
		NSData* data = file.regularFileContents;
		return [[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load the styles file at %@:\n%@.", _path, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
		return nil;
	}
}

- (bool)_parseStyles:(NSAttributedString*)text attrMap:(NSMutableDictionary*)map path:(NSString*)path
{
	ASSERT(map.count == 0);		// can't modify attributes once they have been applied
	
	NSError* error = nil;
	ConfigParser* parser = [[ConfigParser alloc] initWithContent:text.string outError:&error];
	if (!parser)
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't parse the styles file at %@:\n%@.", _path, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
		return false;
	}
	
	NSMutableDictionary* values = [NSMutableDictionary new];
	[parser enumerate:
		^(ConfigParserEntry *entry)
		{
			NSString* name = [entry.key lowercaseString];
			
			NSMutableDictionary* attrs = [NSMutableDictionary new];
			[attrs addEntriesFromDictionary:_baseAttrs];
			[attrs addEntriesFromDictionary:[text fontAttributesInRange:NSMakeRange(entry.offset, 1)]];
			attrs[@"element name"] = name;	// handy to be able to tell whats a string, a comment, etc
			[self _setStyleName:name attrMap:map attrs:attrs];
			
			values[entry.key] = entry.value;
		}
	];
	_values = values;
	
	if (!map[@"normal"] && [path rangeOfString:@"/styles/"].location != NSNotFound)
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Styles file at '%@' is missing a Normal style.", _path];
		[TranscriptController writeError:mesg];
		map[@"normal"] = _baseAttrs;
	}
	return true;
}

- (void)_setStyleName:(NSString*)name attrMap:(NSMutableDictionary*)map attrs:(NSDictionary*)attrs
{
	if (!map[name])
	{
		map[name] = [attrs copy];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Styles file at '%@' has a duplicate %@ style.", _path, name];
		[TranscriptController writeError:mesg];
	}
}

@end
