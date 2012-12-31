#import "Language.h"

#import "Assert.h"
#import "ConditionalGlob.h"
#import "ConfigParser.h"
#import "RegexStyler.h"
#import "Utils.h"

@implementation Language

- (id)initWithParser:(ConfigParser*)parser outError:(NSError**)error
{
	NSMutableArray* globs = [NSMutableArray new];
	NSMutableArray* errors = [NSMutableArray new];
	
	NSMutableArray* names = [NSMutableArray new];
	NSMutableArray* patterns = [NSMutableArray new];
	NSMutableArray* lines = [NSMutableArray new];
	
	[names addObject:@"Default"];
	
	[parser enumerate:
		^(ConfigParserEntry* entry)
		{
			if ([entry.key isEqualToString:@"Language"])
			{
				if (_language)
					[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
				
				_language = entry.value;
			}
			else if ([entry.key isEqualToString:@"LineComment"])
			{
				if (_lineComment)
					[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
				
				_lineComment = entry.value;
			}
			else if ([entry.key isEqualToString:@"Word"])	// TODO: reserved
			{
//				if (_lineComment)
//					[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
				
//				_lineComment = entry.value;
			}
			
			else if ([entry.key isEqualToString:@"Globs"])
			{
				[globs addObjectsFromArray:[Utils splitString:entry.value by:@" "]];
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

	if (!_language)
		[errors addObject:@"Language key is missing"];
	if (globs.count == 0)
		[errors addObject:@"Globs key is missing"];
	if (patterns.count == 0)
		[errors addObject:@"failed to find a language element"];
	
	_glob = [[ConditionalGlob alloc] initWithGlobs:globs];
	_styler = [self _createStyler:names patterns:patterns lines:lines errors:errors];

	if (errors.count > 0)
	{
		NSString* mesg = [errors componentsJoinedByString:@", "];
		mesg = [Utils titleCase:mesg];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
	}
	
	return errors.count == 0 ? self : nil;
}

- (NSString*)description
{
	return _language;
}

- (RegexStyler*)_createStyler:(NSArray*)names patterns:(NSArray*)patterns lines:(NSArray*)lines errors:(NSMutableArray*)errors
{
	ASSERT(patterns.count + 1 == names.count);
	
	if ([self _preflightPatterns:patterns lines:lines errors:errors])
	{
		NSArray* groups = [Utils mapArray:patterns block:
			^id (NSString* p) {return [NSString stringWithFormat:@"(%@)", p];}];
		NSString* pattern = [groups componentsJoinedByString:@"|"];

		NSError* error = nil;
		NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;
		NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
		if (!error)
		{
			return [[RegexStyler alloc] initWithRegex:re elementNames:names];
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
		return nil;
	}
}

- (bool)_preflightPatterns:(NSArray*)patterns lines:(NSArray*)lines errors:(NSMutableArray*)errors
{
	ASSERT(patterns.count == lines.count);
	
	NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;

	NSUInteger oldErrCount = errors.count;
	for (NSUInteger i = 0; i < patterns.count; ++i)
	{
		NSString* pattern = patterns[i];
				
		NSError* error = nil;
		NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
		if (error)
		{
			NSString* reason = [error localizedFailureReason];
			[errors addObject:[NSString stringWithFormat:@"regex on line %@ failed to parse: %@", lines[i], reason]];
		}
		else if (re.numberOfCaptureGroups > 0)
		{
			[errors addObject:[NSString stringWithFormat:@"regex on line %@ should use non-capturing parentheses, i.e. (?:pattern)", lines[i]]];
		}
	}
	
	return oldErrCount == errors.count;
}

@end
