#import "FileHandleCategory.h"

#include <sys/ioctl.h>
#import "DataCategory.h"

@implementation NSFileHandle (FileHandleCategory)

- (NSString*)readLine
{
    NSMutableData* data = [NSMutableData new];

	@try
	{
		while (true)
		{
			NSData* buffer = [self readDataOfLength:1];
			if (buffer.length == 0)
				break;
			
			const char* chars = (const char*) buffer.bytes;
			if (chars[0] == '\n')
				break;
			
			[data appendData:buffer];
		}
	}
	@catch (NSException *exception)
	{
		LOG("Error", "error reading: %s", STR(exception.reason));
	}

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

// From http://www.cocoabuilder.com
- (NSData*)availableDataNonBlocking;
{
    return [self _readDataOfLengthNonBlocking:UINT_MAX];
}

- (NSData*)_readDataOfLengthNonBlocking:(unsigned int)length;
{
    unsigned int readLength;
	
    readLength = [self _availableByteCountNonBlocking];
    readLength = (readLength < length) ? readLength : length;
	
    if (readLength == 0)
        return nil;
	
    return [self readDataOfLength:readLength];
}

- (unsigned int)_availableByteCountNonBlocking
{
    int numBytes;
    int fd = [self fileDescriptor];
	
    if (ioctl(fd, FIONREAD, (char*) &numBytes) == -1)
        [NSException raise:NSFileHandleOperationException format:@"ioctl() Err # %d", errno];
	
    return (unsigned int) numBytes;
}

@end
