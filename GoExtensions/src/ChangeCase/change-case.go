// Adds menu items to upper and lower case selections.
package main

import (
    "encoding/binary"
    "fmt"
    "net"
    "os"
)

var connection *net.TCPConn

func write(message string) {
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

func read() string {
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

func main() {
    var addr = "127.0.0.1:5331"
    var address, err = net.ResolveTCPAddr("tcp", addr)
    if err != nil {
        fmt.Fprintf(os.Stderr, "ResolveTCPAddr failed:\n", err)
        os.Exit(1)
    }

    connection, err = net.DialTCP("tcp", nil, address)
    if err != nil {
        fmt.Fprintf(os.Stderr, "net.DialTCP failed: %s\n", err)
        os.Exit(1)
    }
    defer connection.Close()

    var message = `{"Call": "register_extension", "Name": "change-case", "Version": "1.0", "URL": "https://github.com/jesse99/mimsy"}`
    write(message)

    var reply = read()
    fmt.Fprintf(os.Stdout, "reply from server=%s\n", string(reply))
}
