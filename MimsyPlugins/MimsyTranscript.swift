import Cocoa

@objc public enum TranscriptStyle: Int
{
    /// No special formatting.
    case Plain = 1
    
    /// Used for status messages. Usually appears rather prominently.
    case Info
    
    /// Used by builders to display the command being executed.
    case Command
    
    /// Used by builders to display the stdout of tools.
    case Stdout

    /// Used by builders to display the stderr of tools.
    case Stderr
    
    /// Same as Stderr.
    case Error
}

/// Helper used to communicate with Mimsy's transcript window.
@objc public protocol MimsyTranscript
{
    /// Writes the text to the transcript window. Note that this will not add a new line.
    func write(style: TranscriptStyle, text: String)
}

public extension MimsyTranscript
{
    /// Writes the string to the transcript window.
    public func writeText(style: TranscriptStyle, _ format: String, _ args: CVarArgType...)
    {
        let text = String(format: format, arguments: args)
        write(style, text: text)
    }

    /// Writes the string and a new line to the transcript window.
    public func writeLine(style: TranscriptStyle, _ format: String, _ args: CVarArgType...)
    {
        let text = String(format: format, arguments: args)
        write(style, text: text + "\n")
    }
}
