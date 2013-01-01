#import "TextStyles.h"

#import "Assert.h"
#import "ConfigParser.h"
#import "Paths.h"
#import "TranscriptController.h"
#import "Utils.h"

static NSString* _path;					// path to the styles file
static NSDictionary* _baseAttrs;		// attributes
static NSMutableDictionary* _attrMap;	// element name => attributes
static NSColor* _backColor;

@implementation TextStyles

+ (void)setup
{
	ASSERT(_baseAttrs == nil);
	
	NSString* dir = [Paths installedDir:@"styles"];
	_path = [dir stringByAppendingPathComponent:@"Default.rtf"];
	LOG_DEBUG("Text", "Loading styles from %s", STR(_path));

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
	_baseAttrs = attrs;
	
	NSMutableDictionary* map = [NSMutableDictionary new];
	NSAttributedString* text = [TextStyles _loadStyles];
	if (!text || ![TextStyles _parseStyles:text attrMap:map])
		map[@"Default"] = _baseAttrs;
	_attrMap = map;
	
	NSColor* color = [Utils readMetaDataFrom:_path named:@"mimsy-back-color"];
	_backColor = color ? color : [NSColor whiteColor];
}

+ (NSDictionary*)fallbackStyle
{
	return _baseAttrs;
}

+ (NSDictionary*)attributesForElement:(NSString*)name
{
	NSDictionary* result = _attrMap[name];
	if (!result)
	{
		LOG_WARN("Text", "Couldn't find element %s in the styles file", STR(name));
		result = _attrMap[@"Default"];
		_attrMap[name] = result;
	}
	
	return result;
}

+ (NSColor*)backColor
{
	return _backColor;
}

+ (NSAttributedString*)_loadStyles
{
	NSURL* url = [NSURL fileURLWithPath:_path];
	
	NSError* error = nil;
	NSUInteger options = NSFileWrapperReadingImmediate | NSFileWrapperReadingWithoutMapping;
	NSFileWrapper* file = [[NSFileWrapper alloc] initWithURL:url options:options error:&error];
	if (!error)
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

+ (bool)_parseStyles:(NSAttributedString*)text attrMap:(NSMutableDictionary*)map
{
	ASSERT(map.count == 0);		// can't modify attributes once they have been applied
	
	NSError* error = nil;
	ConfigParser* parser = [[ConfigParser alloc] initWithContent:text.string outError:&error];
	if (error)
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't parse the styles file at %@:\n%@.", _path, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
		return false;
	}
	
	[parser enumerate:
		^(ConfigParserEntry *entry)
		{
			NSMutableDictionary* attrs = [NSMutableDictionary new];
			[attrs addEntriesFromDictionary:_baseAttrs];
			[attrs addEntriesFromDictionary:[text fontAttributesInRange:NSMakeRange(entry.offset, 1)]];
			[TextStyles setStyleName:entry.key attrMap:map attrs:attrs];
		}
	];
	
	if (!map[@"Default"])
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Styles file at '%@' is missing a Default style.", _path];
		[TranscriptController writeError:mesg];
		map[@"Default"] = _baseAttrs;
	}
	return true;
}

+ (void)setStyleName:(NSString*)name attrMap:(NSMutableDictionary*)map attrs:(NSDictionary*)attrs
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