#import "ExtensionListener.h"

#include <sys/socket.h>
#include <netinet/tcp.h>
#include <netinet/in.h>
#import "Logger.h"

#import "ExtensionConnection.h"

const int port = 5331;

static CFSocketRef _acceptSocket;

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
