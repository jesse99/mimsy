// Adds menu items to upper and lower case selections.
package main

import (
    "encoding/binary"
    "fmt"
    "net"
    "os"
)

var connection *net.TCPConn

// Note that, for now, Mimsy only responds to extensions in the interval between Mimsy
// sending a notification to the extension and the extension telling Mimsy that it has
// finished processing the notification. TODO: Allowing extensions to communicate with
// Mimsy at arbitrary times is certainly possible but it's not clear how useful that
// would be and to support it we'd probably want to have the extension register to open
// up a second socket so that Mimsy can do asynchronous reads using NSInputStream.
func writeMessage(message string) {
    var size = make([]byte, 4)
    binary.BigEndian.PutUint32(size, uint32(len(message)))

    var _, err = connection.Write(size)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Write to server failed: %s\n", err)
        os.Exit(1)
    }

    _, err = connection.Write([]byte(message))
    if err != nil {
        fmt.Fprintf(os.Stderr, "Write to server failed: %s\n", err)
        os.Exit(1)
    }
}

func readMessage() string {
    var size = make([]byte, 4)
    var _, err = connection.Read(size)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Read from server failed: %s\n", err)
        os.Exit(1)
    }

    var bytes = binary.BigEndian.Uint32(size)

    var message = make([]byte, bytes)
    _, err = connection.Read(message)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Read from server failed: %s\n", err)
        os.Exit(1)
    }

    return string(message)
}

func on_register(name, version, url string) {
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

    var message = readMessage()
    fmt.Fprintf(os.Stdout, " read %s\n", message)

    // TODO: check that it is on_register
    message = fmt.Sprintf(`{"Method": "register_extension", "Name": "%s", "Version": "%s", "URL": "%s"}`, name, version, url)
    writeMessage(message)
}

func on_register_completed() {
    var message = `{"Method": "on_register_completed"}`
    writeMessage(message)
}

func main() {
    on_register("change-case", "1.0", "https://github.com/jesse99/mimsy")
    defer connection.Close()

    on_register_completed()
}
