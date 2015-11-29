import Cocoa
import MimsyPlugins

enum TaskError: ErrorType
{
    case GenericError(text: String)
    case ProcessError(status: Int32, stdout: String, stderr: String)
}

func readToEOF(name: String, _ file: NSFileHandle) throws -> String
{
    let data = file.readDataToEndOfFile()   // zero bytes is not an error (e.g. for stderr)
    if let result = NSString(data: data, encoding: NSUTF8StringEncoding)
    {
        return result as String
    }
    else
    {
        throw TaskError.GenericError(text: "failed to convert \(name) to UTF8")
    }
}

class StdGoFormat: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerOnSave(onSave)
        }
        
        return nil
    }
    
    func onSave(view: MimsyTextView)
    {
        if let name = view.language?.name
        {
            if name == "go"
            {                
                let stdoutP = NSPipe()
                let stderrP = NSPipe()
                let stdinP = NSPipe()
                
                let task = NSTask()
                task.launchPath = "/opt/local/bin/gofmt"
                task.arguments = []
                task.standardOutput = stdoutP
                task.standardError = stderrP
                task.standardInput = stdinP
                
                let data = view.text.dataUsingEncoding(NSUTF8StringEncoding)
                stdinP.fileHandleForWriting.writeData(data!)    // should always be able to convert to UTF8
                stdinP.fileHandleForWriting.closeFile()
                
                task.launch()
                
                do
                {
                    let stdout = try readToEOF("stdout", stdoutP.fileHandleForReading)
                    if task.terminationStatus != 0
                    {
                        let stderr = try readToEOF("stderr", stderrP.fileHandleForReading)
                        throw TaskError.ProcessError(status: task.terminationStatus, stdout: stdout, stderr: stderr)
                    }

                    view.setText(stdout, undoText: "Format")
                }
                catch TaskError.GenericError(let text)
                {
                    log("Error", "error running gofmt: %@", text)
                }
                catch TaskError.ProcessError(let status, let stdout, let stderr)
                {
                    log("Error", "gofmt exited with code \(status)")
                    
                    if !stdout.isEmpty
                    {
                        log("Error", "stdout: %@", stdout)
                    }
                    
                    if !stderr.isEmpty
                    {
                        log("Error", "stderr: %@", stderr)
                    }
                }
                catch
                {
                    log("Error", "unknown gofmt error")
                }
            }
        }
    }
}
