import Cocoa
import MimsyPlugins

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
                stdinP.fileHandleForWriting.writeData(data!)
                stdinP.fileHandleForWriting.closeFile()
                
                let stdout = stdoutP.fileHandleForReading
                let stderr = stderrP.fileHandleForReading
                task.launch()
                
                if let result = NSString(data: stdout.readDataToEndOfFile(), encoding: NSUTF8StringEncoding)
                {
                    if task.terminationStatus == 0
                    {
                        view.setText(result as String, undoText: "Format")
                    }
                    else
                    {
                        log("Error", "gofmt exited with code \(task.terminationStatus)")
                        
                        if result.length > 0
                        {
                            log("Error", "stdout: %@", result)
                        }
                        
                        if let err = NSString(data: stderr.readDataToEndOfFile(), encoding: NSUTF8StringEncoding)
                        {
                            if err.length > 0
                            {
                                log("Error", "stderr: %@", err)
                            }
                        }
                    }
                }
                // TODO: handle encoding failures better
            }
        }
    }
}
