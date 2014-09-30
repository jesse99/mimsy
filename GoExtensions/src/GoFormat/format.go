// This extension will re-format go code just before go language
// documents are saved.
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
)

func logVerbose(verbose bool, format string, args ...interface{}) {
	var topic = "GoFormat"
	if verbose {
		topic += ":Verbose"
	}

	var text = fmt.Sprintf(format, args...)
	var line = fmt.Sprintf("%s\f%s", topic, text)
	ioutil.WriteFile("/Volumes/Mimsy/log/line", []byte(line), 0644)
}

func rewriteFile(path string) {
	// Read the document.
	var oldBytes, err = ioutil.ReadFile(path)
	if err != nil {
		logVerbose(false, "read file error: %s", err)
		return
	}

	// Re-format it.
	var command = exec.Command("gofmt", "--tabwidth=4")
	command.Stdin = bytes.NewReader(oldBytes)

	var stdout, stderr bytes.Buffer
	command.Stdout = &stdout
	command.Stderr = &stderr
	err = command.Run()
	if err != nil {
		logVerbose(true, "%s", err)
		logVerbose(true, "%s", string(stderr.Bytes()))
		ioutil.WriteFile("/Volumes/Mimsy/beep", []byte{}, 0644)
		return
	}

	// Write it back out.
	ioutil.WriteFile(path, stdout.Bytes(), 0644)
}

func main() {
	fmt.Println("name\fGoFormat")
	fmt.Println("version\f1.0")
	fmt.Println("watch\f1.0\f/Volumes/Mimsy/text-window/1/user-saving")
	fmt.Println("")

	var reader = bufio.NewReader(os.Stdin)
	for true {
		// We only watch one file so we don't care about the path that changed.
		var _, err = reader.ReadString('\n')
		if err != nil {
			break
		}

		var language, _ = ioutil.ReadFile("/Volumes/Mimsy/text-window/1/language")
		if string(language) == "go" {
			rewriteFile("/Volumes/Mimsy/text-window/1/text")
		}
		fmt.Println("false")
	}
}