import Cocoa

@objc public enum TranscriptStyle: Int
{
    /// No special formatting.
    case plain = 1
    
    /// Used for status messages. Usually appears rather prominently.
    case info
    
    /// Used by builders to display the command being executed.
    case command
    
    /// Used by builders to display the stdout of tools.
    case stdout

    /// Used by builders to display the stderr of tools.
    case stderr
    
    /// Same as Stderr.
    case error
}

/// Used to display status or error messages.
@objc public protocol MimsyTranscript
{    
    /// Writes the text to the transcript window. Note that this will not add a new line.
    func write(_ style: TranscriptStyle, text: String)
}

public extension MimsyTranscript
{
    /// Writes the string to the transcript window.
    public func writeText(_ style: TranscriptStyle, _ format: String, _ args: CVarArg...)
    {
        let text = String(format: format, arguments: args)
        write(style, text: text)
    }

    /// Writes the string and a new line to the transcript window.
    public func writeLine(_ style: TranscriptStyle, _ format: String, _ args: CVarArg...)
    {
        let text = String(format: format, arguments: args)
        write(style, text: text + "\n")
    }
}
