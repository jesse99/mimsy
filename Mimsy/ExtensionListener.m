#import "ExtensionListener.h"

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
typedef void (^MessageHandler)(NSDictionary* message);

@interface ExtensionConnection : NSObject

- (id)init:(CFSocketNativeHandle)socketH;

- (void)open;
- (void)close;

- (void)sendNotification:(NSString*)method;

@property (readonly) NSString* name;
@property (readonly) NSString* version;
@property (readonly) NSString* url;

@end

@interface ExtensionConnection () <NSStreamDelegate>
@end

// -----------------------------------------------------------------------------------------------------------
static NSMutableArray* _extensions;

@implementation ExtensionConnection
{
    CFSocketNativeHandle _socket;
    NSMutableDictionary* _callbacks;
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
        _callbacks = [NSMutableDictionary new];
        _name = @"";
        
        _callbacks[@"register_extension"] = ^(NSDictionary* message){_name = message[@"Name"]; _version = message[@"Version"]; _url = message[@"URL"];};
    }
    return self;
}

- (void)_onRegisterExtension
{
    
}

- (void)_onNotificationCompleted
{
    
}

- (void)open
{
    LOG("Extensions", "Opening connection to extension");
    [_extensions addObject:self];
    
    [self sendNotification:@"on_register"];
    
    [self _writeMessage:@"{\"Method\": \"on_register\"}"];
    if (_socket < 0)
        return;

    NSDictionary* message = [self _readMessageWithTimeout];
    if (!message)
        return;
    
    NSString* method = [message objectForKey:@"Method"];
    if (![method isEqualToString:@"register_extension"])
    {
        LOG("Error", "Expected 'register_extension' but found '%s' from extension %s", STR(method), STR(_name));
        [self close];
        return;
    }

    // TODO: read until we get notification_completed
    // TODO: make sure that register_extension was called
    message = [self _readMessageWithTimeout];
    if (!message)
        return;
    
    method = [message objectForKey:@"Method"];
    if (![method isEqualToString:@"notification_completed"])
    {
        LOG("Error", "Expected 'notification_completed' but found '%s' from extension %s", STR(method), STR(_name));
        [self close];
        return;
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

- (void)sendNotification:(NSString*)method
{
    [self _writeMessage:[NSString stringWithFormat:@"{\"Method\": \"%@\"}", method]];
    
    while (_socket >= 0)
    {
        NSDictionary* message = [self _readMessageWithTimeout];
        if (!message)
        {
            LOG("Error", "Timed out waiting for notification_completed from %s extension connection", STR(_name));
            [self close];
            break;
        }
        
        NSString* method = [message objectForKey:@"Method"];
        if ([method isEqualToString:@"notification_completed"])
            break;
        
        MessageHandler callback = [_callbacks objectForKey:method];
        if (callback)
        {
            callback(message);
        }
        else
        {
            LOG("Error", "Bad method '%s' from extension %s", STR(method), STR(_name));
            [self close];
        }
    }
}

- (NSDictionary*)_readMessageWithTimeout
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

    return nil;
}

- (NSDictionary*)_readMessage
{
    NSDictionary* message = nil;
    
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

                if (_shouldLog("Extensions"))   // TODO: make this Verbose
                {
                    NSString* text = [NSString stringWithCString:payload encoding:NSUTF8StringEncoding];
                    if (bytesToRead < 256)
                        LOG("Extensions", "received '%s' from %s endpoint", STR(text), STR(_name));
                    else
                        LOG("Extensions", "received '%s...%s' from %s endpoint", STR([text substringToIndex:60]), STR([text substringFromIndex:bytesToRead-60]), STR(_name));
                }
                
                NSError* error = nil;
                NSData* data = [NSData dataWithBytesNoCopy:payload length:bytesToRead freeWhenDone:false];
                message = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (!message)
                {
                    NSString* reason = [error localizedFailureReason];
                    LOG("Error", "Failed to decode message from %s extension connection: %s", STR(_name), STR(reason));
                    if (!_shouldLog("Extensions"))   // TODO: make this Verbose
                    {
                        NSString* text = [NSString stringWithCString:payload encoding:NSUTF8StringEncoding];
                        LOG("Error", "Message was: %s", STR(text));
                    }
                    [self close];
                }
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
            if (errno == ECONNRESET)
                LOG("Extensions", "%s extension closed its connection", STR(_name));
            else
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
                if (errno == ECONNRESET)
                    LOG("Extensions", "%s extension closed its connection", STR(_name));
                else
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

@implementation ExtensionListener

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
