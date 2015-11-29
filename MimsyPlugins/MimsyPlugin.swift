import Cocoa

/// This is the base class that plugins inherit from. Often only onLoad
/// is overriden.
public class MimsyPlugin: NSObject {
    /// Mimsy will instantiate plugins when it loads their bundles.
    public init(fromApp app: MimsyApp, bundle: NSBundle)
    {
        self.app = app
        self.bundle = bundle
    }
    
    /// Called by Mimsy after the plugin is instantiated. Note that
    /// this is called multiple times with increasing stage numbers:
    /// * Stage 0 is called as plugins load. Plugins seldom use this.
    /// * Stage 1 is normally used by the built-in plugins to initialize themselves.
    /// * Stage 2 is normally used by custom plugins to initialize themselves.
    /// * Stage 3 can be used by plugins that want to execute after other plugins have initialized.
    ///
    /// - Returns: nil if the plugin was able to load or an error message if it
    /// failed to load (or doesn't want to run).
    public func onLoad(stage: Int) -> String?
    {
        return nil
    }
    
    /// Called just before Mimsy exits (assuming it exits normally).
    public func onUnload()
    {
    }
    
    /// Depending upon whether the logging.mimsy settings file enables the topic
    /// this will add a new log line to Mimsy's log. Note that the log is normally
    /// at ~/Library/Logs/mimsy.log.
    ///
    /// - Parameter topic: Typically "Plugins", "Plugins:Verbose", or a custom topic name.
    /// - Parameter format: NSString style [format string](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/Strings/Articles/formatSpecifiers.html).
    /// - Parameter args: Optional arguments to feed into the format string.
    public func log(topic: String, _ format: String, _ args: CVarArgType...)
    {
        let text = String(format: format, arguments: args)
        app.logLine(topic, text: text)
    }
    
    /// Returns the full path to an executable or nil.
    public func findExe(name: String) -> String?
    {
        let pipe = NSPipe()
        
        let task = NSTask()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "which \(name)"]
        task.environment = app.environment()
        task.standardOutput = pipe
        
        task.launch()
        task.waitUntilExit()
        
        var result: String? = nil
        if task.terminationStatus == 0
        {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            result = NSString(data: data, encoding: NSUTF8StringEncoding) as String?
            result = result?.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
        }
                
        return result
    }
    
    /// Plugins should use MimsyApp whenever they want to communicate with
    /// Mimsy.
    public let app: MimsyApp
    
    /// The plugin's bundle.
    public let bundle: NSBundle
}

