// Adds menu items to upper and lower case selections.
package main

import (
    "mimsy"
)

func main() {
    mimsy.OpenConnection() 
    mimsy.RegisterExtension("change-case", "1.0", "https://github.com/jesse99/mimsy")
    defer mimsy.CloseConnection()
}
