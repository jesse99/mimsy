/// Handles the IPC between Mimsy and extensions.
// TODO: probably want example usage here
package mimsy

import (
    "encoding/binary"
    "encoding/json"
    "fmt"
    "net"
    "os"
)

/// This is called after the connection to Mimsy is established but
/// before the extension starts processing notifications. This is where
/// you'd register callbacks to respond to notifications from Mimsy.
/// The returned values are used notify mimsy of details about the 
/// extension being loaded. Name and version can be arbitrary strings.
/// Url should point to the extension's web site.
type LoadingCallback func() (name, version, url string)

// TODO: May want an UnloadingCallback. Can we make any guarantees
// about it?

/// Waits for notifications from Mimsy and dispatches to the callbacks
/// registered by LoadingCallback.
func DispatchEvents(loading LoadingCallback) {
	openConnection()
	defer closeConnection()
		
	notificationHandlers["on_register"] = func () {
		var name, version, url = loading()
		var message = onRegisterReply{"register_extension", name, version, url}
		writeMessage(message)		
	}
	
	for true {
		var message onNotificationRequest
		readMessage(&message)
		
		var handler, found = notificationHandlers[message.Method]
		if found {
			Log("Extensions", "read %+v", message)
			handler()
			notificationCompleted()
		} else {
			// We shouldn't get any notifications we haven't registered for.
			Log("Error", "%s received a bad method: '%s'", extensionName, message.Method)
			break
		}
	}
}

// ---- Internal Items ----------------------------------------------------------------
var connection *net.TCPConn

var extensionName = ""

var notificationHandlers = map[string]func() {}

// TODO: notifications with additional state should place it into a followup request
type onNotificationRequest struct {
    Method string
}

type onRegisterReply struct {
    Method string
    Name string
    Version string
    URL string
}

type notificationCompletedReply struct {
    Method string
}

func openConnection() {
    var addr = "127.0.0.1:5331"
    var address, err = net.ResolveTCPAddr("tcp", addr)
    if err != nil {
        fmt.Fprintf(os.Stderr, "ResolveTCPAddr failed:\n", err) // can't use log if we don't have a connectionn...
        os.Exit(1)
    }

    connection, err = net.DialTCP("tcp", nil, address)
    if err != nil {
        fmt.Fprintf(os.Stderr, "DialTCP failed: %s\n", err)
        os.Exit(1)
    }
}

func closeConnection() {
    connection.Close()
}

// Called after an extension finishes processing a notification. Extensions may do
// whatever they wish between the notification and notificationCompleted but they
// can't wait too long in between sending Mimsy messages (where too long is on the
// order of a second).
func notificationCompleted() {
    var message = notificationCompletedReply{"notification_completed"}
    writeMessage(message)
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

