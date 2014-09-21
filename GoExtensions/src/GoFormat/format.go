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

func logErr(format string, args ...interface{}) {
	var text = fmt.Sprintf(format, args...)
	var line = fmt.Sprintf("GoFormat:%s", text)
	ioutil.WriteFile("/Volumes/Mimsy/log/line", []byte(line), 0644)
	//fmt.Fprintln(os.Stderr, line)

	ioutil.WriteFile("/Volumes/Mimsy/beep", []byte{}, 0644)
}

func rewriteFile(path string) {
	// Read the document.
	var oldBytes, err = ioutil.ReadFile(path)
	if err != nil {
		logErr("read file error: %s", err)
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
		logErr("gofmt error: %s", err)
		return
	}

	// Write it back out.
	ioutil.WriteFile(path, stdout.Bytes(), 0644)
}

func main() {
	fmt.Println("name:GoFormat")
	fmt.Println("version:1.0")
	fmt.Println("watch:1.0:/Volumes/Mimsy/text-window/1/saving")
	fmt.Println("")

	var reader = bufio.NewReader(os.Stdin)
	for true {
		// We only watch one file so we don't care about the path that changed.
		var _, err = reader.ReadString('\n')

		if err == nil {
			var language, _ = ioutil.ReadFile("/Volumes/Mimsy/text-window/1/language")
			if string(language) == "go" {
				rewriteFile("/Volumes/Mimsy/text-window/1/text")
			}
			fmt.Println("false")
		}
	}
}