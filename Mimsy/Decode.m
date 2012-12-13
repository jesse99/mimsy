#import "Decode.h"

// Returns true if the character is a control character that should not
// appear in source code.
static bool isBadControl(unsigned char b)
{
	if (b < 0x20 && b != '\t' && b != '\n' && b != '\r')
		return true;
	
	else if (b == 0x7F)
		return true;
	
	return false;
}

static bool isValidUTF8(unsigned char b)
{
	bool valid = true;
	
	if (b == 0xC0 || b == 0xC1)
		valid = false;
	
	else if (b >= 0xF5)
		valid = false;
	
	return valid;
}

static bool isValidMacRoman(unsigned char b)
{
	bool valid = true;
	
	if (isBadControl(b))
		valid = false;
	
	return valid;
}

// Apart from the asian languages most utf16 characters will have a zero in
// their high byte. So, if we see enough zeros we'll call the data utf16 (and
// note that utf8 will not have zeros).
static bool looksLikeUTF16(const unsigned char* buffer, bool bigEndian, unsigned long headerBytes)
{
	int zeros = 0;
	int count = 0;
	
	for (int i = 0; i + 1 < headerBytes; i += 2)
	{
		++count;
		
		if (bigEndian)
		{
			if (buffer[i] == 0 && buffer[i + 1] != 0)
				if (isBadControl(buffer[i + 1]))
					return false;
				else
					++zeros;
		}
		else
		{
			if (buffer[i] != 0 && buffer[i + 1] == 0)
				if (isBadControl(buffer[i]))
					return false;
				else
					++zeros;
		}
	}
	
	return zeros > 0.25*count;
}

static bool looksLikeUTF32(const unsigned char* buffer, bool bigEndian, unsigned long headerBytes)
{
	int zeros = 0;
	int count = 0;
	
	for (int i = 0; i + 3 < headerBytes; i += 4)
	{
		++count;
		
		if (bigEndian)
		{
			if (buffer[i] == 0 && buffer[i + 1] == 0 && buffer[i + 2] == 0 && buffer[i + 3] != 0)
				if (isBadControl(buffer[i + 3]))
					return false;
				else
					++zeros;
		}
		else
		{
			if (buffer[i] != 0 && buffer[i + 1] == 0 && buffer[i + 2] == 0 && buffer[i + 3] == 0)
				if (isBadControl(buffer[i]))
					return false;
				else
					++zeros;
		}
	}
	
	return zeros > 0.25*count;
}

// Note that the buffer is not null-terminated.
static bool all_chars(const unsigned char* buffer, bool (*predicate)(unsigned char), unsigned long len)
{
	for (unsigned long i = 0; i < len; ++i)
	{
		if (!predicate(buffer[i]))
			return false;
	}
	return true;
}

static NSStringEncoding getEncoding(NSData* data, unsigned long* skipBytes)
{
	NSStringEncoding encoding = 0;
	const int HeaderBytes = 2*64;
	
	unsigned char* buffer = alloca(HeaderBytes);
	[data getBytes:buffer length:HeaderBytes];
	unsigned long length = MIN([data length], HeaderBytes);
		
	// Check for a BOM.
	if (buffer[0] == 0x00 && buffer[1] == 0x00 && buffer[2] == 0xFE && buffer[3] == 0xFF)
	{
		encoding = NSUTF32BigEndianStringEncoding;
		*skipBytes = 4;
	}
	else if (buffer[0] == 0xFF && buffer[1] == 0xFE && buffer[2] == 0x00 && buffer[3] == 0x00)
	{
		encoding = NSUTF32LittleEndianStringEncoding;
		*skipBytes = 4;
	}
	else if (buffer[0] == 0xFE && buffer[1] == 0xFF)
	{
		encoding = NSUTF16BigEndianStringEncoding;
		*skipBytes = 2;
	}
	else if (buffer[0] == 0xFF && buffer[1] == 0xFE)
	{
		encoding = NSUTF16LittleEndianStringEncoding;
		*skipBytes = 2;
	}
	
	// See if it looks like utf-32.
	if (encoding == 0)
	{
		if (looksLikeUTF32(buffer, true, length))
			encoding = NSUTF32BigEndianStringEncoding;
		else if (looksLikeUTF32(buffer, false, length))
			encoding = NSUTF32LittleEndianStringEncoding;
	}
	
	// See if it looks like utf-16.
	if (encoding == 0)
	{
		if (looksLikeUTF16(buffer, true, length))
			encoding = NSUTF16BigEndianStringEncoding;
		else if (looksLikeUTF16(buffer, false, length))
			encoding = NSUTF16LittleEndianStringEncoding;
	}
	
	// See if it could be utf-8.
	if (encoding == 0)
	{
		if (all_chars(buffer, isValidUTF8, length))
			encoding = NSUTF8StringEncoding;
	}
	
	// Fall back on Mac OS Roman.
	if (encoding == 0)
	{
		if (all_chars(buffer, isValidMacRoman, length))
			encoding = NSMacOSRomanStringEncoding;
	}
	
	return encoding;
}

@implementation Decode

- (id)initWithData:(NSData*)data;
{
	NSAssert(data, @"data is nil");

    self = [super init];
    if (self)
	{
		if ([data length] > 0)
		{
			unsigned long skipBytes = 0;
			NSStringEncoding encoding = getEncoding(data, &skipBytes);
			if (encoding)
			{
				if (skipBytes > 0)
					data = [data subdataWithRange:NSMakeRange(skipBytes, [data length] - skipBytes)];
				NSString* str = [[NSString alloc] initWithData:data encoding:encoding];

				// The first few bytes of most legacy documents will look like utf8 so
				// if we couldn't decode it using utf8 we need to fall back onto Mac
				// OS Roman.
				if (str == nil && encoding == NSUTF8StringEncoding)
				{
					encoding = NSMacOSRomanStringEncoding;
					str = [[NSString alloc] initWithData:data encoding:encoding];
				}
				
				if (str != nil)
				{
					[self setText:str];
					[self setEncoding:encoding];
				}
			}
			if ([self text] == nil)
				[self setError:@"Couldn't read the file as Unicode or Mac OS Roman."];	// should only happen if there are embedded control characters in the header
		}
		else
		{
			[self setText:@""];
			[self setEncoding:NSUTF8StringEncoding];
		}
    }
    
    return self;
}

@end
