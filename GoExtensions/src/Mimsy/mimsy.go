/// Library used to communicate with Mimsy.
// TODO: probably want example usage here
package mimsy

import (
    "encoding/binary"
    "encoding/json"
    "fmt"
    "net"
    "os"
)

/// This opens a TCP connection to Mimsy and is normally the very first thing an extension does.
func OpenConnection() {
    var addr = "127.0.0.1:5331"
    var address, err = net.ResolveTCPAddr("tcp", addr)
    if err != nil {
        fmt.Fprintf(os.Stderr, "ResolveTCPAddr failed:\n", err)
        os.Exit(1)
    }

    connection, err = net.DialTCP("tcp", nil, address)
    if err != nil {
        fmt.Fprintf(os.Stderr, "DialTCP failed: %s\n", err)
        os.Exit(1)
    }

    var message onNotificationMethod
    readMessage(&message)
    if message.Method != "on_register" {
        fmt.Fprintf(os.Stderr, "Expected on_register method but received: %s\n", message.Method)
        os.Exit(1)
    }
    fmt.Fprintf(os.Stdout, " read %+v\n", message)
}

/// Closes down the TCP connection to Mimsy.
func CloseConnection() {
    connection.Close()
}

/// Called after OpenConnection to inform Mimsy of details about the extension.
/// Omitting this call is a clean way for extensions to signal Mimsy that they
/// don't wish to run.
func RegisterExtension(name, version, url string) {
    var message = registerExtensionMethod{"register_extension", name, version, url}
    writeMessage(message)
    
    NotificationCompleted()
}

/// Called after an extension finishes processing a notification. Extensions may do
/// whatever they wish between the notification and NotificationCompleted but they
/// can't wait too long in between sending Mimsy messages (where too long is on the
/// order of a second).
func NotificationCompleted() {
    var message = notificationCompletedMethod{"notification_completed"}
    writeMessage(message)
}

// ---- Internal Items ----------------------------------------------------------------

var connection *net.TCPConn

type onNotificationMethod struct {
    Method string
}

type registerExtensionMethod struct {
    Method string
    Name string
    Version string
    URL string
}

type notificationCompletedMethod struct {
    Method string
}

// Note that, for now, Mimsy only responds to extensions in the interval between Mimsy
// sending a notification to the extension and the extension telling Mimsy that it has
// finished processing the notification. TODO: Allowing extensions to communicate with
// Mimsy at arbitrary times is certainly possible but it's not clear how useful that
// would be and to support it we'd probably want to have the extension register to open
// up a second socket so that Mimsy can do asynchronous reads using NSInputStream.
func writeMessage(message interface{}) {
    var payload, err = json.Marshal(message)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Failed to json.Marshal %+v: %s\n", message, err)
        os.Exit(1)
    }

    var size = make([]byte, 4)
    binary.BigEndian.PutUint32(size, uint32(len(payload)))

    _, err = connection.Write(size)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Write to server failed: %s\n", err)
        os.Exit(1)
    }

    _, err = connection.Write(payload)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Write to server failed: %s\n", err)
        os.Exit(1)
    }
}

func readMessage(message interface{}) {
    var size = make([]byte, 4)
    var _, err = connection.Read(size)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Read from server failed: %s\n", err)
        os.Exit(1)
    }

    var bytes = binary.BigEndian.Uint32(size)

    var payload = make([]byte, bytes)
    _, err = connection.Read(payload)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Read from server failed: %s\n", err)
        os.Exit(1)
    }

    err = json.Unmarshal(payload, message)
    if err != nil {
        fmt.Fprintf(os.Stderr, "json.Unmarshal failed: %s\n", err)
        os.Exit(1)
    }
}

