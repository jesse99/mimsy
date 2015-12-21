#import "HelpItem.h"

@implementation HelpItem
{
	NSArray* _contexts;
	NSString* _title;
	NSURL* _url;
}

- (id)initFromPath:(MimsyPath*)path err:(NSError**)error
{
	self = [super init];
	
	if (self)
	{
        NSString* fileName = [[path popExtension] lastComponent];
		NSArray* parts = [fileName componentsSeparatedByString:@"-"];
		if (parts.count >= 2)
		{
			_contexts = [parts subarrayWithRange:NSMakeRange(0, parts.count - 1)];
			_title = parts[parts.count - 1];
			_url = [[NSURL alloc] initFileURLWithPath:path.asString isDirectory:FALSE];
			return self;
		}
		else
		{
			if (error)
			{
				NSString* mesg = [NSString stringWithFormat:@"'%@' isn't a valid help file name: expected a dash separating the context name from the menu title.", [path lastComponent]];
				NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
				*error = [NSError errorWithDomain:@"mimsy" code:5 userInfo:dict];
			}
			return nil;
		}
	}
	
	return self;
}

static NSString* getSubstr(NSString* value, NSString* beginChar, NSString* endChar)
{
	NSUInteger beginIndex = [value rangeOfString:beginChar].location;
	NSUInteger endIndex   = endChar ? [value rangeOfString:endChar].location : value.length;
	
	if (beginIndex != NSNotFound && endIndex != NSNotFound)
	{
		return [value substringWithRange:NSMakeRange(beginIndex + 1, endIndex - beginIndex - 1)];
	}
	else
	{
		return nil;	
	}
}

// {context names separated by dashes}[title]url.
- (id)initFromSetting:(NSString*)fileName value:(NSString*)value err:(NSError**)error
{
	self = [super init];
	
	if (self)
	{
		NSString* names = getSubstr(value, @"{", @"}");
		NSString* title = getSubstr(value, @"[", @"]");
		NSString* url = getSubstr(value, @"]", nil);
		
		if (names && title && url && names.length > 0 && title.length > 0 && url.length > 0)
		{
			_contexts = [names componentsSeparatedByString:@"-"];
			_title = title;
			_url = [[NSURL alloc] initWithString:url];
			if (!_url)
				_url = [[NSURL alloc] initFileURLWithPath:url isDirectory:FALSE];

			if (!_url)
			{
				if (error)
				{
					NSString* mesg = [NSString stringWithFormat:@"'%@' from %@ isn't a valid RFC 2396 URL or file system path.", url, fileName];
					NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
					*error = [NSError errorWithDomain:@"mimsy" code:5 userInfo:dict];
				}
				return nil;
			}
			return self;
		}
		else
		{
			if (error)
			{
				NSString* mesg = [NSString stringWithFormat:@"'%@' from %@ isn't a valid ContextHelp value: expected {context names separated by dashes}[title]url or path.", value, fileName];
				NSDictionary* dict = @{NSLocalizedFailureReasonErrorKey:mesg};
				*error = [NSError errorWithDomain:@"mimsy" code:5 userInfo:dict];
			}
			return nil;
		}
	}
	
	return self;
}

- (bool)matchesContext:(NSString*)context
{
	return [_contexts containsObject:context];
}

- (NSString*)title
{
	return _title;
}

- (NSURL*)url
{
	return _url;
}

@end
