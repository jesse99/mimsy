#import "ExtensionConnection.h"

#include <sys/socket.h>

static NSMutableArray* _extensions;
static NSMutableDictionary* _handlers;

@implementation ExtensionConnection
{
    CFSocketNativeHandle _socket;
}

+ (void)registerHandler:(NSString*)name handler:(MessageHandler)handler
{
    ASSERT(!_handlers[name]);
    _handlers[name] = handler;
}

- (id)init:(CFSocketNativeHandle)socketH
{
    ASSERT(socketH >= 0);
    
    if (!_extensions)
    {
        _extensions = [NSMutableArray new];
        _handlers = [NSMutableDictionary new];
    }
    
    self = [super init];
    if (self != nil)
    {
        _socket = socketH;
        _name = @"";
        
        // TODO: Should we special case extensions with the same name?
        _handlers[@"register_extension"] = ^(NSDictionary* message){_name = message[@"Name"]; _version = message[@"Version"]; _url = message[@"URL"];};
    }
    return self;
}

- (void)open
{
    LOG("Extensions", "Opening connection to extension");
    [_extensions addObject:self];
    
    [self sendNotification:@"on_register"];
    
    if (_socket >= 0 && _name.length == 0)
    {
        // This is not neccesarily an error but it does indicate that the extension doesn't want to run.
        LOG("Extension", "register_extension was not called for extension %s", STR(_name));
        [self close];
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
        
        MessageHandler handler = [_handlers objectForKey:method];
        if (handler)
        {
            handler(message);
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