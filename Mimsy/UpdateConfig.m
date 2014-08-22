#import "UpdateConfig.h"

static NSMutableAttributedString* loadPrefFile(NSString* path, NSError** outError)
{
	NSURL* url = [NSURL fileURLWithPath:path];
	
	NSUInteger options = NSFileWrapperReadingImmediate | NSFileWrapperReadingWithoutMapping;
	NSFileWrapper* file = [[NSFileWrapper alloc] initWithURL:url options:options error:outError];
	if (file)
	{
		NSData* data = file.regularFileContents;
		return [[NSMutableAttributedString alloc] initWithRTF:data documentAttributes:NULL];
	}
	else
	{
		return nil;
	}
}

static bool setPref(NSMutableString* contents, NSString* key, NSString* value, NSError** outError)
{
	key = [NSRegularExpression escapedPatternForString:key];
	value = [NSRegularExpression escapedTemplateForString:value];
	
	NSString* pattern = [NSString stringWithFormat:@"^(%@\\s*:\\s*)([^\n]+)", key];
	NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:outError];
	
	NSUInteger replacements = 0;
	if (re)
	{
		NSRange range = NSMakeRange(0, contents.length);
		NSString* template = [NSString stringWithFormat:@"$1%@", value];
		replacements = [re replaceMatchesInString:contents options:0 range:range withTemplate:template];
	}
	
	return replacements > 0;
}

static void addPref(NSMutableString* contents, NSString* key, NSString* value)
{
	if (![contents endsWith:@"\n"])
		[contents appendString:@"\n"];
	
	[contents appendString:key];
	[contents appendString:@": "];
	[contents appendString:value];
	[contents appendString:@"\n"];
}

static bool writePref(NSString* path, NSAttributedString* contents, NSError** outError)
{
	NSDictionary* attrs = @{NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType};
	NSData* data = [contents dataFromRange:NSMakeRange(0, contents.length) documentAttributes:attrs error:outError];
	if (data)
	{
		NSURL* url = [NSURL fileURLWithPath:path];
		NSFileWrapper* file = [[NSFileWrapper alloc] initRegularFileWithContents:data];
		return [file writeToURL:url options:NSFileWrapperWritingAtomic originalContentsURL:nil error:outError];
	}

	return false;
}

bool updatePref(NSString* path, NSString* key, NSString* value, NSError** outError)
{
	NSMutableAttributedString* contents = loadPrefFile(path, outError);
	if (contents)
	{
		NSMutableString* text = contents.mutableString;
		if (setPref(text, key, value, outError))
		{
			return writePref(path, contents, outError);
		}
		else
		{
			addPref(text, key, value);
			return writePref(path, contents, outError);
		}
	}
	return false;
}
