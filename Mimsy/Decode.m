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

static bool all_chars(const unsigned char* buffer, bool (*predicate)(unsigned char))
{
	for (const unsigned char* p = buffer; *p; p++)
	{
		if (!predicate(*p))
			return false;
	}
	return true;
}

static int getEncoding(NSData* data, int* skipBytes)
{
	int encoding = 0;
	const int HeaderBytes = 2*64;
	
	unsigned char* buffer = alloca(HeaderBytes);
	[data getBytes:buffer length:HeaderBytes];
		
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
//	if (encoding == 0)
//	{
//		if (looksLikeUTF32(buffer, true, buffer.Length))
//			encoding = NSUTF32BigEndianStringEncoding;
//		else if (looksLikeUTF32(buffer, false, buffer.Length))
//			encoding = NSUTF32LittleEndianStringEncoding;
//	}
	
	// See if it looks like utf-16.
//	if (encoding == 0)
//	{
//		if (looksLikeUTF16(buffer, true, buffer.Length))
//			encoding = NSUTF16BigEndianStringEncoding;
//		else if (looksLikeUTF16(buffer, false, buffer.Length))
//			encoding = NSUTF16LittleEndianStringEncoding;
//	}
	
	// See if it could be utf-8.
	if (encoding == 0)
	{
		if (all_chars(buffer, isValidUTF8))
			encoding = NSUTF8StringEncoding;
	}
	
	// Fall back on Mac OS Roman.
	if (encoding == 0)
	{
		if (all_chars(buffer, isValidMacRoman))
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
			int skipBytes;
			int encoding = getEncoding(data, &skipBytes);
			[self setEncoding:encoding];
			[self setError:@"not implemented"];
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
