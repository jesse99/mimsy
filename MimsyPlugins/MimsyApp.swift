import Cocoa

/// This is used by plugins to communicate with the top level of Mimsy.
@objc public protocol MimsyApp
{
    /// Normally plugins will use the MimsyPlugin log method instead of this.
    func logLine(topic: NSString, text: NSString)
}
