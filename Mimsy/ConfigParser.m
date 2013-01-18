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

#import "Assert.h"

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

- (id)initWithPath:(NSString*)path outError:(NSError**)error
{
	NSString* contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
	if (contents != nil)
		self = [self initWithContent:contents outError:error];
	else
		self = nil;
	
	return self;
}

- (id)initWithContent:(NSString*)contents outError:(NSError**)error
{
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

- (void)parseLine:(NSString*)contents error:(NSError**)error
{	
	unichar ch = [contents characterAtIndex:_index];
	if ([_letters characterIsMember:ch])
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
	else if (ch == '#')
	{
		[self parseCommentLine:contents error:error];
	}
	else if ([_whitespace characterIsMember:ch])
	{
		[self parseBlankLine:contents error:error];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Expected line %lu to start with a letter, a #, or be blank.", _line];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:2 userInfo:dict];
	}
}

// key := [^\n\r:]+
- (NSString*)parseKey:(NSString*)contents
{
	NSUInteger begin = _index;
	while (_index < _length)
	{
		unichar ch = [contents characterAtIndex:_index];
		if (ch == '\r' || ch == '\r' || ch == ':')
			break;
		else
			_index += 1;
	}
	
	ASSERT(begin < _index);
	return [contents substringWithRange:NSMakeRange(begin, _index - begin)];
}

// colon := [ \t]* ':'
- (void)parseColon:(NSString*)contents error:(NSError**)error
{
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
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Expected a colon on line %lu.", _line];
		NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
		*error = [NSError errorWithDomain:@"mimsy" code:3 userInfo:dict];
	}
}

// value := [^\r\n]* eol
- (NSString*)parseValue:(NSString*)contents error:(NSError**)error
{
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
- (void)parseCommentLine:(NSString*)contents error:(NSError**)error
{
	while (_index < _length)
	{
		unichar ch = [contents characterAtIndex:_index];
		if (ch == '\r' || ch == '\n')
			break;
		else
			_index += 1;
	}
	
	[self parseEOL:contents error:error];
}

// blank := [ \t]* eol
- (void)parseBlankLine:(NSString*)contents error:(NSError**)error
{
	while (_index < _length)
	{
		unichar ch = [contents characterAtIndex:_index];
		if ([_spaces characterIsMember:ch])
			_index += 1;
		else
			break;
	}
	
	[self parseEOL:contents error:error];
}

// eol := '\r\n' | '\r' | '\n'
- (void)parseEOL:(NSString*)contents error:(NSError**)error
{
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
