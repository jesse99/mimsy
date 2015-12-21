// It's a bit lame to use yet another file format, but the principle places
// that we use it have some unusual constraints:
// 1) Language files revolve around regexen which are sufficiently ugly to
// write that I don't want to have to escape them.
// 2) For style files we need to associate the embedded RTF style information
// with keys. So the parser has to be able to parse attributed strings and
// must return offsets as well as key/values.
//
// This rules out pretty much all the common formats except maybe INI files
// of which this format is very close to a subset of.
#import "ConfigParser.h"

@implementation ConfigParserEntry
@end

@implementation ConfigParser
{
	NSMutableArray* _entries;
	NSCharacterSet* _letters;
	NSCharacterSet* _spaces;
	NSCharacterSet* _whitespace;
	NSUInteger _index;
	NSUInteger _length;
	NSUInteger _line;
}

- (id)initWithPath:(MimsyPath*)path outError:(NSError**)error
{
	NSString* contents = [NSString stringWithContentsOfFile:path.asString encoding:NSUTF8StringEncoding error:error];
	if (contents)
		self = [self initWithContent:contents outError:error];
	else
		self = nil;
	
	return self;
}

- (id)initWithContent:(NSString*)contents outError:(NSError**)error
{
	ASSERT(error != NULL);
	
	_entries = [NSMutableArray new];
	_letters = [NSCharacterSet letterCharacterSet];
	_spaces = [NSCharacterSet whitespaceCharacterSet];
	_whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	_index = 0;
	_length = contents.length;
	_line = 1;

	*error = nil;
	while (_index < _length && *error == nil)
	{
		[self parseLine:contents error:error];
		_line += 1;
	}

	return *error == nil ? self : nil;
}

- (bool)parseLine:(NSString*)contents error:(NSError**)error
{
	ASSERT(error != NULL);
	
	unichar ch = [contents characterAtIndex:_index];
	if (ch == '#')
	{
		[self parseCommentLine:contents error:error];
	}
	else if ([_whitespace characterIsMember:ch])
	{
		[self parseBlankLine:contents error:error];
	}
	else if (ch != ':')
	{
		ConfigParserEntry* entry = [ConfigParserEntry new];
		entry.offset = _index;
		entry.key = [self parseKey:contents];
		entry.line = _line;
		
		[self parseColon:contents error:error];
		if (*error == nil)
		{
			entry.value = [self parseValue:contents error:error];
			[_entries addObject:entry];
		}
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Expected line %lu to start with a non-colon, a #, or be blank.", _line];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:2 userInfo:dict];
	}
	return *error == NULL;
}

// key := [^\n\r: ]+
- (NSString*)parseKey:(NSString*)contents
{
	NSUInteger begin = _index;
	while (_index < _length)
	{
		unichar ch = [contents characterAtIndex:_index];
		if (ch == '\r' || ch == '\r' || ch == '\t' || ch == ':')
			break;
		else
			_index += 1;
	}
	
	ASSERT(begin < _index);
	NSString* key = [contents substringWithRange:NSMakeRange(begin, _index - begin)];
	return [key stringByTrimmingCharactersInSet:_whitespace];
}

// colon := [ \t]* ':'
- (bool)parseColon:(NSString*)contents error:(NSError**)error
{
	ASSERT(error != NULL);
	
	while (_index < _length)
	{
		unichar ch = [contents characterAtIndex:_index];
		if ([_spaces characterIsMember:ch])
			_index += 1;
		else
			break;
	}

	if (_index < _length && [contents characterAtIndex:_index] == ':')
	{
		++_index;
	}
	else if (_index < _length)
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Expected a colon on line %lu but found %C.", _line, [contents characterAtIndex:_index]];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:3 userInfo:dict];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Expected a colon but found EOF."];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:3 userInfo:dict];
	}
	return *error == NULL;
}

// value := [^\r\n]* eol
- (NSString*)parseValue:(NSString*)contents error:(NSError**)error
{
	ASSERT(error != NULL);
	
	NSUInteger begin = _index;
	while (_index < _length)
	{
		unichar ch = [contents characterAtIndex:_index];
		if (ch == '\r' || ch == '\n')
			break;
		else
			_index += 1;
	}
	
	[self parseEOL:contents error:error];
	
	NSString* value = [contents substringWithRange:NSMakeRange(begin, _index - begin)];
	return [value stringByTrimmingCharactersInSet:_whitespace];
}

// comment := '#' [^\r\n]* eol
- (bool)parseCommentLine:(NSString*)contents error:(NSError**)error
{
	ASSERT(error != NULL);
	
	while (_index < _length)
	{
		unichar ch = [contents characterAtIndex:_index];
		if (ch == '\r' || ch == '\n')
			break;
		else
			_index += 1;
	}
	
	[self parseEOL:contents error:error];
	return *error == NULL;
}

// blank := [ \t]* eol
- (bool)parseBlankLine:(NSString*)contents error:(NSError**)error
{
	ASSERT(error != NULL);
	
	while (_index < _length)
	{
		unichar ch = [contents characterAtIndex:_index];
		if ([_spaces characterIsMember:ch])
			_index += 1;
		else
			break;
	}
	
	[self parseEOL:contents error:error];
	return *error == NULL;
}

// eol := '\r\n' | '\r' | '\n'
- (bool)parseEOL:(NSString*)contents error:(NSError**)error
{
	ASSERT(error != NULL);
	
	if (_index < _length)
	{
		unichar ch0 = [contents characterAtIndex:_index];	// need to be careful here so we don't screw up _line
		unichar ch1 = _index+1 < _length ? [contents characterAtIndex:_index+1] : '\x0';
		if (ch0 == '\r' && ch1 == '\n')
		{
			_index += 2;
		}
		else if (ch0 == '\r' || ch0 == '\n')
		{
			_index += 1;
		}
		else
		{
			NSString* mesg = [[NSString alloc] initWithFormat:@"Expected EOL on line %lu, but found '%c'.", _line, ch0];
			NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
			*error = [NSError errorWithDomain:@"mimsy" code:3 userInfo:dict];
		}
	}
	return *error == NULL;
}

- (NSUInteger)length
{
	return _entries.count;
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	return _entries[index];
}

-(void)enumerate:(void (^)(ConfigParserEntry* entry))block
{
	[_entries enumerateObjectsUsingBlock:
	 ^ (ConfigParserEntry* entry, NSUInteger index, BOOL* stop)
	{
		(void) index;
		(void) stop;
		block(entry);
	}];
}

-(NSString*) valueForKey:(NSString*)key
{
	for (ConfigParserEntry* entry in _entries)
	{
		if ([entry.key isEqualToString:key])
		{
			return entry.value;
		}
	}
	return nil;
}

@end
