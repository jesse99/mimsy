// Adds menu items to upper and lower case selections.
package main

import (
	"Mimsy"
)

func loading() (name, version, url string) {
	return "change-case", "1.0", "https://github.com/jesse99/mimsy"
}

func main() {
	mimsy.DispatchEvents(loading)
}
