#import "DataCategory.h"

#include <openssl/bio.h>
#include <openssl/evp.h>

@implementation NSData (NSDataCategory)

// Based on: http://www.cocoawithlove.com/2009/06/base64-encoding-options-on-mac-and.html
- (NSString*)base64EncodedString
{
    // Construct an OpenSSL context
    BIO* context = BIO_new(BIO_s_mem());
	BIO_set_flags(context, BIO_FLAGS_BASE64_NO_NL);
	
    // Tell the context to encode base64
    BIO* command = BIO_new(BIO_f_base64());
    context = BIO_push(command, context);
	
    // Encode all the data
    BIO_write(context, self.bytes, (int) self.length);
    (void) BIO_flush(context);
	
    // Get the data out of the context
    char* outputBuffer;
    NSUInteger outputLength = (NSUInteger) BIO_get_mem_data(context, &outputBuffer);
	if (outputLength > 0 && outputBuffer[outputLength-1] == '\n')
		--outputLength;
    NSString* encodedString = [[NSString alloc] initWithBytes:outputBuffer length:outputLength encoding:NSUTF8StringEncoding];
    BIO_free_all(context);
	
    return encodedString;
}

+ (NSData*)dataByBase64DecodingString:(NSString*)decode
{
    decode = [decode stringByAppendingString:@"\n"];
    NSData* data = [decode dataUsingEncoding:NSASCIIStringEncoding];
	
    // Construct an OpenSSL context
    BIO* command = BIO_new(BIO_f_base64());
    BIO* context = BIO_new_mem_buf((void*) data.bytes, (int) data.length);
	
    // Tell the context to encode base64
    context = BIO_push(command, context);
	
    // Encode all the data
    NSMutableData* outputData = [NSMutableData data];
	
	#define BUFFSIZE 256
    int len;
    char inbuf[BUFFSIZE];
    while ((len = BIO_read(context, inbuf, BUFFSIZE)) > 0)
    {
        [outputData appendBytes:inbuf length:(NSUInteger)len];
    }
	
    BIO_free_all(context);
    [data self]; // extend GC lifetime of data to here
	
    return outputData;
}

// Lightly edited from stack overflow.
- (NSRange)rangeOfData:(NSData*)needle
{
    const void* bytes = [self bytes];
    NSUInteger length = [self length];
    const void* searchBytes = [needle bytes];
    NSUInteger searchLength = [needle length];
    NSUInteger searchIndex = 0;
	
    NSRange foundRange = {NSNotFound, searchLength};
    for (NSUInteger index = 0; index < length; index++)
	{
        // The current character matches.
        if (((char*)bytes)[index] == ((char*)searchBytes)[searchIndex])
		{
            // Store found location if not done earlier.
            if (foundRange.location == NSNotFound)
			{
                foundRange.location = index;
            }
            // Increment search character index to check for match.
            searchIndex++;
            // All search character match.
            // Break search routine and return found position.
            if (searchIndex >= searchLength)
			{
                return foundRange;
            }
        }
        // Match does not continue.
        // Return to the first search character.
        // Discard former found location.
        else
		{
            searchIndex = 0;
            foundRange.location = NSNotFound;
        }
    }
    return foundRange;
}

@end
