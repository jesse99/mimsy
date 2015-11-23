/// Used to interact with the Mimsy application (as opposed to Mimsy subsystems).
package mimsy

import (
    "fmt"
)

func Log(topic, format string, args ...interface{}) {
    var message = logMessage{"log", topic, fmt.Sprintf(format, args...)}
    writeMessage(message)
}

// ---- Internal Items ----------------------------------------------------------------
type logMessage struct {
    Method string
    Topic string
    Text string
}

