import Cocoa
import MimsyPlugins

enum TaskError: Error
{
    case genericError(text: String)
    case processError(status: Int32, stdout: String, stderr: String)
}

func readToEOF(_ name: String, _ file: FileHandle) throws -> String
{
    let data = file.readDataToEndOfFile()
    if let result = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
    {
        return result as String
    }
    else
    {
        throw TaskError.genericError(text: "failed to convert \(name) to UTF8")
    }
}

class StdGoFormat: MimsyPlugin
{
    var path: String? = nil
    
    override func onLoad(_ stage: Int) -> String?
    {
        var err: String? = nil
        
        if stage == 1
        {
            path = app.findExe("gofmt")
            if path == nil
            {
                err = "couldn't find a path to gofmt"
            }

           app.registerTextView(.saving, onSave)
        }
        
        return err
    }
    
    func onSave(_ view: MimsyTextView)
    {
        switch view.language?.name
        {
        case .some(let lanuage) where lanuage == "go":
            let data = view.text.data(using: String.Encoding.utf8)

            if (data?.count ?? 0) < 50*1024    // TODO: getting hangs with large documents
            {
                let stdoutP = Pipe()
                let stderrP = Pipe()
                let stdinP = Pipe()
                
                let task = Process()
                task.launchPath = path!
                task.arguments = []
                task.standardOutput = stdoutP
                task.standardError = stderrP
                task.standardInput = stdinP
                
                stdinP.fileHandleForWriting.write(data!)    // should always be able to convert to UTF8
                stdinP.fileHandleForWriting.closeFile()
                
                task.launch()
                task.waitUntilExit()
                
                do
                {
                    let stdout = try readToEOF("stdout", stdoutP.fileHandleForReading)
                    if task.terminationStatus != 0
                    {
                        let stderr = try readToEOF("stderr", stderrP.fileHandleForReading)
                        throw TaskError.processError(status: task.terminationStatus, stdout: stdout, stderr: stderr)
                    }
                    
                    // This should only be empty if the document is empty (which is certainly
                    // possible). To be safe we won't whack the document if gofmt returns nothing.
                    if !stdout.isEmpty
                    {
                        view.setText(stdout, undoText: "Format")
                    }
                }
                catch TaskError.genericError(let text)
                {
                    app.log("Error", "error running gofmt: %@", text)
                }
                catch TaskError.processError(let status, let stdout, let stderr)
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
            }
            
        default:
            break
        }
    }
}
