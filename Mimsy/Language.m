#import "Language.h"

#import "AppDelegate.h"
#import "ConditionalGlob.h"
#import "ConfigParser.h"
#import "RegexStyler.h"
#import "Settings.h"
#import "Utils.h"

@implementation Language
{
    Settings* _settings;
    NSMutableArray* _settingKeys;
    NSMutableArray* _settingValues;
    NSDictionary* _patterns;
}

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
        NSMutableDictionary* epatterns = [NSMutableDictionary new];
		
		NSMutableArray* names = [NSMutableArray new];
		NSMutableArray* patterns = [NSMutableArray new];
		NSMutableArray* lines = [NSMutableArray new];
        __block NSString* word = nil;
		__block NSMutableArray* numbers = [NSMutableArray new];
		__block NSUInteger wordLine = 0;
		
		[names addObject:@"normal"];
		
        _settingKeys = [NSMutableArray new];
        _settingValues = [NSMutableArray new];
		[parser enumerate:
			^(ConfigParserEntry* entry)
			{
				NSString* key = [entry.key lowercaseString];
				if ([key isEqualToString:@"language"])
				{
                    if (self->_name)
						[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
					
                    self->_name = entry.value;
				}
				else if ([key isEqualToString:@"linecomment"])
				{
                    if (self->_lineComment)
						[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
					
                    self->_lineComment = entry.value;	
				}
				else if ([key isEqualToString:@"word"])
				{
                    if (self->_word)
						[errors addObject:[NSString stringWithFormat:@"duplicate %@ key on line %ld", entry.key, entry.line]];
					
					word = entry.value;
					wordLine = entry.line;
				}
				
				else if ([key isEqualToString:@"globs"])
				{
					[globs addObjectsFromArray:[entry.value splitByString:@" "]];
                    [self->_settingKeys addObject:entry.key];
                    [self->_settingValues addObject:entry.value];
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
							[errors addObject:[NSString stringWithFormat:@"glob on line %ld failed to compile as a regex: %@", entry.line, error.localizedFailureReason]];
						}
					}
					else
					{
						[errors addObject:[NSString stringWithFormat:@"expected space separating a glob from a regex on line %ld", entry.line]];
					}
				}
                else if ([key isEqualToString:@"contexthelp"] || [key isEqualToString:@"searchin"])
                {
                    // Lame special case for some settings that tend not to compile as regexen.
                    [self->_settingKeys addObject:entry.key];
                    [self->_settingValues addObject:entry.value];
                }
				else
				{
                    // Note that it is OK to use the same element name multiple times.
                    if ([key isEqualToString:@"number"] || [key isEqualToString:@"float"])
                        [numbers addObject:entry.value];
                    
                    [names addObject:key];
                    [patterns addObject:entry.value];
                    [lines addObject:[NSNumber numberWithUnsignedLong:entry.line]];
                    
                    NSMutableArray* evalue = epatterns[key];
                    if (!evalue)
                    {
                        evalue = [NSMutableArray new];
                        epatterns[key] = evalue;
                    }
                    [evalue addObject:entry.value];
                    
                    [self->_settingKeys addObject:entry.key];
                    [self->_settingValues addObject:entry.value];
				}
			}
		];

		if (!word)
			word = @"[\\p{Ll}\\p{Lu}\\p{Lt}\\p{Lo}_][\\w_]*";

		NSError* e = nil;
		NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace;
		_word = [[NSRegularExpression alloc] initWithPattern:word options:options error:&e];
		if (!_word)
		{
			[errors addObject:[NSString stringWithFormat:@"regex on line %ld failed to compile: %@", wordLine, e.localizedFailureReason]];
		}
        
        numbers = [numbers map:^id(NSString* element) {
            return [NSString stringWithFormat:@"(%@)", element];
        }];
        NSString* pattern = [numbers componentsJoinedByString:@"|"];
        _number = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&e];   // we'll report any errors below

		if (!_name)
			[errors addObject:@"Language key is missing"];
		if (globs.count == 0)
			[errors addObject:@"Globs key is missing"];
		if (patterns.count == 0)
			[errors addObject:@"failed to find a language element"];
		
		_glob = [[ConditionalGlob alloc] initWithGlobs:globs regexen:regexen conditionals:conditionals];
		_shebangs = shebangs;
		_styler = [self _createStyler:names patterns:patterns lines:lines errors:errors];
        _patterns = epatterns;  // note that we want to do this via an atomic operation because getPatterns can be called from a thread
		
        AppDelegate* app = (AppDelegate*) [NSApp delegate];
        _settings = [[Settings alloc] init:_name context:app];
        for (NSUInteger i = 0; i < _settingKeys.count; i++)
        {
            [_settings addKey:_settingKeys[i] value:_settingValues[i]];
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

- (NSArray*)settingKeys
{
    return _settingKeys;
}

- (NSArray*)settingValues
{
    return _settingValues;
}

-(id<MimsySettings> __nonnull)settings
{
    return _settings;
}

- (BOOL)matches:(MimsyPath* __nonnull)file
{
    NSString* fileName = file.lastComponent;
    if ([_glob matchName:fileName] == 1)
        return true;
    
    if (_shebangs.count > 0)
    {
        NSFileHandle* handle = [NSFileHandle fileHandleForReadingAtPath:file.asString];
        NSData* data = [handle readDataOfLength:512];
        [handle closeFile];
        
        if (data && data.length > 0)
        {
            NSString* contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            return [_glob matchName:fileName contents:contents] != 0;
        }
    }
    
    return false;
}

- (NSArray<NSString*>* __nonnull)getPatterns:(NSString* __nonnull)element
{
    return _patterns[element.lowercaseString];
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
	ASSERT(patterns.count == names.count-1);
	
    NSArray* regexen = [self _compilePatterns:patterns lines:lines errors:errors];
    return regexen ? [[RegexStyler alloc] initWithRegexen:regexen elementNames:names] : nil;
}

- (NSArray*)_compilePatterns:(NSArray*)patterns lines:(NSArray*)lines errors:(NSMutableArray*)errors
{
	ASSERT(patterns.count == lines.count);
    
    NSMutableArray* regexen = [NSMutableArray new];
			
	NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace | NSRegularExpressionAnchorsMatchLines;

	NSUInteger oldErrCount = errors.count;
	for (NSUInteger i = 0; i < patterns.count; ++i)
	{
		NSString* pattern = patterns[i];
				
		NSError* error = nil;
		NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
        if (!re)
        {
            NSString* reason = [error localizedFailureReason];
            [errors addObject:[NSString stringWithFormat:@"regex on line %@ failed to parse: %@", lines[i], reason]];
            continue;
        }
		if (re.numberOfCaptureGroups > 1)
		{
            [errors addObject:[NSString stringWithFormat:@"regex on line %@ has more than one capture group", lines[i]]];
            continue;
		}
        
        [regexen addObject:re];
	}
    
    return errors.count == oldErrCount ? regexen : nil;
}

@end
