#import "Language.h"

#import "AppSettings.h"
#import "ArrayCategory.h"
#import "Assert.h"
#import "ConditionalGlob.h"
#import "ConfigParser.h"
#import "LocalSettings.h"
#import "RegexStyler.h"
#import "StringCategory.h"
#import "Utils.h"

@implementation Language

- (id)initWithParser:(ConfigParser*)parser outError:(NSError**)error
{
	ASSERT(error != NULL);
	
	self = [super init];
	
	if (self)
	{
		NSMutableArray* globs = [NSMutableArray new];
		NSMutableArray* shebangs = [NSMutableArray new];
		NSMutableArray* regexen = [NSMutableArray new];
		NSMutableArray* conditionals = [NSMutableArray new];
		NSMutableArray* errors = [NSMutableArray new];
		
		NSMutableArray* settingNames = [NSMutableArray new];
		NSMutableArray* settingValues = [NSMutableArray new];
		NSMutableArray* names = [NSMutableArray new];
		NSMutableArray* patterns = [NSMutableArray new];
		NSMutableArray* lines = [NSMutableArray new];
		
		[names addObject:@"normal"];
		
		[parser enumerate:
			^(ConfigParserEntry* entry)
			{
				NSString* key = [entry.key lowercaseString];
				if ([key isEqualToString:@"language"])
				{
					if (_name)
						[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
					
					_name = entry.value;
				}
				else if ([key isEqualToString:@"linecomment"])
				{
					if (_lineComment)
						[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
					
					_lineComment = entry.value;	
				}
				else if ([key isEqualToString:@"word"])	// TODO: reserved
				{
	//				if (_lineComment)
	//					[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
					
	//				_lineComment = entry.value;
				}
				
				else if ([key isEqualToString:@"globs"])
				{
					[globs addObjectsFromArray:[entry.value splitByString:@" "]];
				}
				else if ([key isEqualToString:@"shebang"])
				{
					[shebangs addObject:entry.value];
				}
				else if ([key isEqualToString:@"conditionalglob"])
				{
					NSRange range = [entry.value rangeOfString:@" "];
					if (range.location != NSNotFound)
					{
						NSString* glob = [entry.value substringToIndex:range.location];
						NSString* pattern = [entry.value substringFromIndex:range.location+1];

						NSError* error = nil;
						NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;
						NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
						if (re)
						{
							[regexen addObject:re];
							[conditionals addObject:glob];
						}
						else
						{
							[errors addObject:[NSString stringWithFormat:@"regex on line %ld failed to parse: %@", entry.line, error.localizedFailureReason]];
						}
					}
					else
					{
						[errors addObject:[NSString stringWithFormat:@"expected space separating a glob from a regex on line %ld", entry.line]];
					}
				}
				else if (![AppSettings isSetting:entry.key])
				{
					// Note that it is OK to use the same element name multiple times.
					[names addObject:key];
					[patterns addObject:entry.value];
					[lines addObject:[NSNumber numberWithUnsignedLong:entry.line]];
				}
				else
				{
					[settingNames addObject:entry.key];
					[settingValues addObject:entry.value];
				}
			}
		];

		if (!_name)
			[errors addObject:@"Language key is missing"];
		if (globs.count == 0)
			[errors addObject:@"Globs key is missing"];
		if (patterns.count == 0)
			[errors addObject:@"failed to find a language element"];
		
		_glob = [[ConditionalGlob alloc] initWithGlobs:globs regexen:regexen conditionals:conditionals];
		_shebangs = shebangs;
		_styler = [self _createStyler:names patterns:patterns lines:lines errors:errors];
		
		if (_name)
		{
			_settings = [[LocalSettings alloc] initWithFileName:[NSString stringWithFormat:@"%@ language file", _name]];
			
			for (NSUInteger i = 0; i < settingNames.count; ++i)
			{
				[_settings addKey:settingNames[i] value:settingValues[i]];
			}
		}
		else
		{
			_settings = [[LocalSettings alloc] initWithFileName:@"language file"];
		}

		if (errors.count > 0)
		{
			NSString* mesg = [[errors componentsJoinedByString:@", "] titleCase];
			NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
			*error = [NSError errorWithDomain:@"mimsy" code:4 userInfo:dict];
		}
		
		self = errors.count == 0 ? self : nil;
	}
	
	return self;
}

- (NSString*)description
{
	return _name;
}

// value is formatted as: [C Library]http://www.cplusplus.com/reference/clibrary/
+ (bool)parseHelp:(NSString*)value help:(NSMutableArray*)help
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
		if (re)
		{
			return [[RegexStyler alloc] initWithRegex:re elementNames:names groupToName:groupToName];
		}
		else
		{
			NSString* reason = [error localizedFailureReason];
			[errors addObject:[NSString stringWithFormat:@"aggregate regex failed to parse: %@", reason]];
			freeUIntVector(&groupToName);
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
		if (re)
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
