// This extension adds an item to the Search menu which will find
// control characters and non 7-bit ASCII characters.
package main

// The following can be used to develop this extension without
// having to rebuild or relaunch mimsy:
// export GOPATH=/Users/jessejones/Source/mimsy/GoExtensions
// go install ShowGremlins && cp $GOPATH/bin/ShowGremlins /Users/jessejones/Library/Application\ Support/Mimsy/extensions
import (
	"archive/zip"
	"bufio"
	"encoding/base64"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"unicode/utf16"
)

var code_points []string

func logVerbose(verbose bool, format string, args ...interface{}) {
	var topic = "ShowGremlins"
	if verbose {
		topic += ":Verbose"
	}

	var text = fmt.Sprintf(format, args...)
	var line = fmt.Sprintf("%s\f%s", topic, text)
	ioutil.WriteFile("/Volumes/Mimsy/log/line", []byte(line), 0644)
}

func readSelectionRange() (int, int) {
	var location = 0
	var length = 0

	var text, err = ioutil.ReadFile("/Volumes/Mimsy/text-document/selection-range")
	if err == nil {
		var parts = strings.Split(string(text), "\f")
		location, _ = strconv.Atoi(parts[0])
		length, _ = strconv.Atoi(parts[1])
	}

	return location, length
}

func writeSelectionRange(location, length int) {
	var text = fmt.Sprintf("%d\f%d", location, length)
	ioutil.WriteFile("/Volumes/Mimsy/text-document/selection-range", []byte(text), 0644)
}

func findGremlin(units []uint16, loc int) int {
	for i := loc; i < len(units); i++ {
		if units[i] < 32 {
			if units[i] != '\t' && units[i] != '\n' {
				return i
			}
		} else if units[i] > 126 {
			return i
		}
	}
	return len(units)
}

func loadNames() []string {
	var names []string

	var bytes, err = ioutil.ReadFile("/Volumes/Mimsy/resources-path")
	var p = filepath.Join(string(bytes), "UnicodeNames.zip")

	var action = ""
	var zipReader, err2 = zip.OpenReader(p)
	if err2 != nil {
		action = "open"
		goto failed
	}
	defer zipReader.Close()

	for _, zipFile := range zipReader.File {
		var file, err = zipFile.Open()
		if err != nil {
			action = "open zipped"
			goto failed
		}
		defer file.Close()

		bytes, err = ioutil.ReadAll(file)
		if err != nil {
			action = "read"
			goto failed
		}

		names = strings.Split(string(bytes), "\n")
	}

	return names

failed:
	logVerbose(false, "failed to %s %s: %s", action, p, err)
	return names
}

func findName(n uint16) string {
	var name = "?"

	if int(n) < len(code_points) {
		name = code_points[n]
		if name == "-" {
			name = "invalid code point"
		}
	}

	return fmt.Sprintf("0x%04X %s", n, name)
}

func main() {
	var path = "show-gremlins"

	fmt.Println("name\fShowGremlins")
	fmt.Println("version\f1.0")
	fmt.Println("watch\f1.0\f" + path)
	fmt.Println("")

	// Extensions are reloaded if the directory changes so we need to
	// check to see if we have already added the menu item.
	var installed, _ = ioutil.ReadFile("/Volumes/Mimsy/key-values/show-gremlins")
	if len(installed) == 0 {
		var args = base64.StdEncoding.EncodeToString([]byte("find\fFind Gremlin\f" + path))
		ioutil.ReadFile("/Volumes/Mimsy/actions/add-menu-item/" + args)

		ioutil.WriteFile("/Volumes/Mimsy/key-values/show-gremlins", []byte("yes"), 0644)
	}

	var reader = bufio.NewReader(os.Stdin)
	for true {
		// We only watch one file so we don't care about the path that changed.
		var _, err = reader.ReadString('\n')
		if err != nil {
			break
		}

		var text, _ = ioutil.ReadFile("/Volumes/Mimsy/text-document/text")
		if len(text) > 0 {
			// Cocoa uses utf-16 internally so in order for offsets to be correct
			// we'll need to do the same.
			var units = utf16.Encode([]rune(string(text)))
			var loc, length = readSelectionRange()
			var i = findGremlin(units, loc+length)

			var mesg string
			if i < len(units) {
				if len(code_points) == 0 {
					code_points = loadNames()
				}

				mesg = fmt.Sprintf("Found %s.", findName(units[i]))
				writeSelectionRange(i, 1)
			} else {
				// We could support wrapping around (if the FindWraps setting is set)
				// but that works best with Find and Find Again commands.
				mesg = "No gremlins were found after the selection."
				ioutil.WriteFile("/Volumes/Mimsy/beep", []byte("1"), 0644)
			}
			ioutil.WriteFile("/Volumes/Mimsy/transcript/write-info", []byte(mesg), 0644)
		}

		fmt.Println("true")
	}
}