#import "Language.h"

#import "ArrayCategory.h"
#import "Assert.h"
#import "ConditionalGlob.h"
#import "ConfigParser.h"
#import "RegexStyler.h"
#import "StringCategory.h"
#import "Utils.h"

@implementation Language

- (id)initWithParser:(ConfigParser*)parser outError:(NSError**)error
{
	NSMutableArray* globs = [NSMutableArray new];
	NSMutableArray* errors = [NSMutableArray new];
	
	NSMutableArray* names = [NSMutableArray new];
	NSMutableArray* patterns = [NSMutableArray new];
	NSMutableArray* lines = [NSMutableArray new];
	NSMutableArray* help = [NSMutableArray new];
	
	[names addObject:@"Normal"];
	
	[parser enumerate:
		^(ConfigParserEntry* entry)
		{
			if ([entry.key isEqualToString:@"Language"])
			{
				if (_name)
					[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
				
				_name = entry.value;
			}
			else if ([entry.key isEqualToString:@"LineComment"])
			{
				if (_lineComment)
					[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
				
				_lineComment = entry.value;
			}
			else if ([entry.key isEqualToString:@"Help"])
			{
				if (![self _parseHelp:entry.value help:help])
					[errors addObject:[NSString stringWithFormat:@"malformed help on line %ld: expected '[<title>]<url or full path>'", entry.line]];
			}
			else if ([entry.key isEqualToString:@"Word"])	// TODO: reserved
			{
//				if (_lineComment)
//					[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
				
//				_lineComment = entry.value;
			}
			
			else if ([entry.key isEqualToString:@"Globs"])
			{
				[globs addObjectsFromArray:[entry.value splitByString:@" "]];
			}
			else
			{
				// Note that it is OK to use the same element name multiple times.
				[names addObject:entry.key];
				[patterns addObject:entry.value];
				[lines addObject:[NSNumber numberWithUnsignedLong:entry.line]];
			}
		}
	];

	if (!_name)
		[errors addObject:@"Language key is missing"];
	if (globs.count == 0)
		[errors addObject:@"Globs key is missing"];
	if (patterns.count == 0)
		[errors addObject:@"failed to find a language element"];
	
	_glob = [[ConditionalGlob alloc] initWithGlobs:globs];
	_styler = [self _createStyler:names patterns:patterns lines:lines errors:errors];
	_help = help;

	if (errors.count > 0)
	{
		NSString* mesg = [errors componentsJoinedByString:@", "];
		mesg = [mesg titleCase];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
	}
	
	return errors.count == 0 ? self : nil;
}

- (NSString*)description
{
	return _name;
}

// value is formatted as: [C Library]http://www.cplusplus.com/reference/clibrary/
- (bool)_parseHelp:(NSString*)value help:(NSMutableArray*)help
{
	bool parsed = false;
	
	NSRange r1 = [value rangeOfString:@"["];
	NSRange r2 = [value rangeOfString:@"]"];
	if (r1.location != NSNotFound && r2.location != NSNotFound && r2.location > r1.location)
	{
		NSString* title = [value substringWithRange:NSMakeRange(r1.location+1, r2.location-r1.location-1)];
		NSString* loc = [value substringFromIndex:r2.location+1];
		[help addObject:title];
		if ([loc rangeOfString:@"://"].location != NSNotFound)
			[help addObject:[NSURL URLWithString:loc]];
		else
			[help addObject:[NSURL fileURLWithPath:loc]];
		parsed = true;
	}
	
	return parsed;
}

- (RegexStyler*)_createStyler:(NSArray*)names patterns:(NSArray*)patterns lines:(NSArray*)lines errors:(NSMutableArray*)errors
{
	ASSERT(patterns.count + 1 == names.count);
	
	struct UIntVector groupToName = [self _preflightPatterns:patterns lines:lines errors:errors];
	if (groupToName.count > 0)
	{
		NSArray* groups = [patterns map:
			^id (NSString* p) {return [NSString stringWithFormat:@"(%@)", p];}];
		NSString* pattern = [groups componentsJoinedByString:@"|"];

		NSError* error = nil;
		NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;
		NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
		if (!error)
		{
			return [[RegexStyler alloc] initWithRegex:re elementNames:names groupToName:groupToName];
		}
		else
		{
			NSString* reason = [error localizedFailureReason];
			[errors addObject:[NSString stringWithFormat:@"aggregate regex failed to parse: %@", reason]];
			return nil;
		}
	}
	else
	{
		freeUIntVector(&groupToName);
		return nil;
	}
}

- (struct UIntVector)_preflightPatterns:(NSArray*)patterns lines:(NSArray*)lines errors:(NSMutableArray*)errors
{
	ASSERT(patterns.count == lines.count);
		
	struct UIntVector groupToName = newUIntVector();
	reserveUIntVector(&groupToName, patterns.count);
	pushUIntVector(&groupToName, 0);					// group 0 (the entire match) doesn't actually map to an element
	
	NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;

	NSUInteger oldErrCount = errors.count;
	for (NSUInteger i = 0; i < patterns.count; ++i)
	{
		NSString* pattern = patterns[i];
				
		NSError* error = nil;
		NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
		if (!error)
		{
			pushUIntVector(&groupToName, i+1);
			for (int j = 0; j < re.numberOfCaptureGroups; ++j)
			{
				pushUIntVector(&groupToName, i+1);
			}
		}
		else
		{
			NSString* reason = [error localizedFailureReason];
			[errors addObject:[NSString stringWithFormat:@"regex on line %@ failed to parse: %@", lines[i], reason]];
		}
	}
	
	if (errors.count > oldErrCount)
		setSizeUIntVector(&groupToName, 0);
	
	return groupToName;
}

@end
