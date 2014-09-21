#import "FileHandleCategory.h"

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

@end
