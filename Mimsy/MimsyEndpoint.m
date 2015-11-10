#import "MimsyEndpoint.h"

#import <CoreFoundation/CoreFoundation.h>
#include <fcntl.h>
#include <sys/fcntl.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <netinet/in.h>
#import "Logger.h"

const int port = 5331;

static CFSocketRef _acceptSocket;

// -----------------------------------------------------------------------------------------------------------
@interface ExtensionConnection : NSObject

- (id)init:(CFSocketNativeHandle)socketH;

- (void)open;
- (void)close;

@property (readonly) NSString* name;

@end

@interface ExtensionConnection () <NSStreamDelegate>
@end

// -----------------------------------------------------------------------------------------------------------
static NSMutableArray* _extensions;

@implementation ExtensionConnection
{
    CFSocketNativeHandle _socket;
}

- (id)init:(CFSocketNativeHandle)socketH
{
    ASSERT(socketH >= 0);
    
    if (!_extensions)
        _extensions = [NSMutableArray new];
    
    self = [super init];
    if (self != nil)
    {
        _socket = socketH;
        _name = @"";
    }
    return self;
}

- (void)open
{
    LOG("Extensions", "Opening connection to extension");
    [_extensions addObject:self];
    
    NSString* message = [self _readMessageWithTimeout];
    if (message)
    {
        [self _writeMessage:@"OK"];
    }
}

- (void)close
{
    if (_socket >= 0)
    {
        (void) close(_socket);
        _socket = -1;
        [_extensions removeObject:self];
        LOG("Extensions", "Closed connection to %s extension", STR(_name));
    }
}

- (NSString*)_readMessageWithTimeout
{
    double startTime = getTime();

    while (_socket >= 0)
    {
        double currentTime = getTime();
        if (currentTime - startTime > 1.0)
            break;
        
        if ([self _messageAvailable])
            return [self _readMessage];
        
        usleep(100*1000);
    }
    
    LOG("Error", "Timed out reading message from %s extension connection", STR(_name));
    [self close];

    return nil;
}

- (NSString*)_readMessage
{
    NSString* message = nil;
    
    uint32_t bytesToRead;
    if ([self _read:&bytesToRead bytes:sizeof(bytesToRead)])
    {
        bytesToRead = ntohl(bytesToRead);
        
        char* payload = malloc(bytesToRead+1);
        if (payload)
        {
            if ([self _read:payload bytes:bytesToRead])
            {
                payload[bytesToRead] = '\0';
                
                message = [NSString stringWithCString:payload encoding:NSUTF8StringEncoding];
                if (bytesToRead < 256)
                    LOG("Extensions", "received '%s' from %s endpoint", STR(message), STR(_name));
                else
                    LOG("Extensions", "received '%s...%s' from %s endpoint", STR([message substringToIndex:60]), STR([message substringFromIndex:bytesToRead-60]), STR(_name));
            }
            else
            {
                LOG("Error", "Failed to read %d byte payload for %s extension connection", bytesToRead, STR(_name));
                [self close];
            }
            free(payload);
        }
        else
        {
            LOG("Error", "Failed to allocate %d byte payload for %s extension connection", bytesToRead, STR(_name));
            [self close];
        }
    }
    else
    {
        LOG("Error", "Failed to read payload size for %s extension connection", STR(_name));
        [self close];
    }
    
    return message;
}

- (bool)_messageAvailable
{
    while (_socket >= 0)
    {
        char buffer[4];
        ssize_t read = recv(_socket, buffer, sizeof(buffer), MSG_PEEK);
        if (read == sizeof(buffer))
        {
            return true;
        }
        else if (read >= 0)
        {
            return false;
        }
        else if (errno != EINTR)
        {
            LOG("Error", "Failed to peek message for %s extension connection: %s", STR(_name), strerror(errno));
            [self close];
        }
    }
    
    return false;
}

- (bool)_read:(void*)buffer bytes:(NSUInteger)bytes
{
    ssize_t bytesRead = 0;
    
    while (bytesRead < bytes && _socket >= 0)
    {
        ssize_t read = recv(_socket, buffer + bytesRead, bytes - (size_t) bytesRead, 0);
        if (read < 0)
        {
            if (errno != EINTR)
            {
                LOG("Error", "Failed to read %lu bytes for %s extension connection: %s", (unsigned long)bytes, STR(_name), strerror(errno));
                [self close];
            }
        }
        else
        {
            bytesRead += read;
        }
    }
    
    return bytesRead == bytes;
}

- (bool)_writeMessage:(NSString*)message
{
    const char* data = message.UTF8String;
    unsigned long len = strlen(data);
    
    uint32_t bytesToWrite = htonl(len);
    return [self _write:&bytesToWrite bytes:sizeof(bytesToWrite)] && [self _write:data bytes:len];
}

- (bool)_write:(const void*)buffer bytes:(NSUInteger)bytes
{
    ssize_t bytesSent = 0;
    
    while (bytesSent < bytes && _socket >= 0)
    {
        ssize_t written = send(_socket, buffer + bytesSent, bytes - (size_t) bytesSent, 0);
        if (written < 0)
        {
            if (errno != EINTR)
            {
                LOG("Error", "Failed to send %lu bytes for %s extension connection: %s", (unsigned long)bytes, STR(_name), strerror(errno));
                [self close];
            }
        }
        else
        {
            bytesSent += written;
        }
    }
    
    return bytesSent == bytes;
}

@end

// -----------------------------------------------------------------------------------------------------------
static void acceptCallback(CFSocketRef socket, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
    UNUSED(socket, callbackType, address, info);
    
    CFSocketNativeHandle socketH = *(CFSocketNativeHandle*)data;
    
    const int yes = 1;
    (void) setsockopt(socketH, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes));
    
    ExtensionConnection* connection = [[ExtensionConnection alloc] init:socketH];
    [connection open];
}

@implementation MimsyEndpoint

+ (void) setup
{
    _acceptSocket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_STREAM, 0, kCFSocketAcceptCallBack, acceptCallback, NULL);
    if (!_acceptSocket)
    {
        LOG("Error", "Failed to create the accept socket for mimsy extensions");
        return;
    }
    
    const int yes = 1;
    (void) setsockopt(CFSocketGetNative(_acceptSocket), SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);

    CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8*)&addr, sizeof(addr));
    CFSocketError err = CFSocketSetAddress(_acceptSocket, address);
    if (err)
    {
        LOG("Error", "Mimsy accept socket CFSocketSetAddress failed (%ld)", err);
        CFSocketInvalidate(_acceptSocket);
        CFRelease(_acceptSocket);
        _acceptSocket = NULL;
        return;
    }
    
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _acceptSocket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CFRelease(source);
}

@end
