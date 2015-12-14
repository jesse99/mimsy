import Cocoa
import MimsyPlugins

enum TaskError: ErrorType
{
    case GenericError(text: String)
    case ProcessError(status: Int32, stdout: String, stderr: String)
}

func readToEOF(name: String, _ file: NSFileHandle) throws -> String
{
    let data = file.readDataToEndOfFile()
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
    var path: String? = nil
    
    override func onLoad(stage: Int) -> String?
    {
        var err: String? = nil
        
        if stage == 1
        {
            path = app.findExe("gofmt")
            if path == nil
            {
                err = "couldn't find a path to gofmt"
            }

            app.registerTextView(.Saving, onSave)
        }
        
        return err
    }
    
    func onSave(view: MimsyTextView)
    {
        switch view.language?.name
        {
        case .Some(let lanuage) where lanuage == "go":
            let stdoutP = NSPipe()
            let stderrP = NSPipe()
            let stdinP = NSPipe()
            
            let task = NSTask()
            task.launchPath = path!
            task.arguments = []
            task.standardOutput = stdoutP
            task.standardError = stderrP
            task.standardInput = stdinP
            
            let data = view.text.dataUsingEncoding(NSUTF8StringEncoding)
            stdinP.fileHandleForWriting.writeData(data!)    // should always be able to convert to UTF8
            stdinP.fileHandleForWriting.closeFile()
            
            task.launch()
            task.waitUntilExit()
            
            do
            {
                let stdout = try readToEOF("stdout", stdoutP.fileHandleForReading)
                if task.terminationStatus != 0
                {
                    let stderr = try readToEOF("stderr", stderrP.fileHandleForReading)
                    throw TaskError.ProcessError(status: task.terminationStatus, stdout: stdout, stderr: stderr)
                }
                
                // This should only be empty if the document is empty (which is certainly
                // possible). To be safe we won't whack the document if gofmt returns nothing.
                if !stdout.isEmpty
                {
                    view.setText(stdout, undoText: "Format")
                }
            }
            catch TaskError.GenericError(let text)
            {
                app.log("Error", "error running gofmt: %@", text)
            }
            catch TaskError.ProcessError(let status, let stdout, let stderr)
            {
                app.log("Error", "gofmt exited with code \(status)")
                
                if !stdout.isEmpty
                {
                    app.log("Error", "stdout: %@", stdout)
                }
                
                if !stderr.isEmpty
                {
                    app.log("Error", "stderr: %@", stderr)
                }
            }
            catch
            {
                app.log("Error", "unknown gofmt error")
            }
            
        default:
            break
        }
    }
}
