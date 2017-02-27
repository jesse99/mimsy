import Foundation

public struct MimsyError: Error
{
    public init(_ format: String, _ args: CVarArg...)
    {
        text = String(format: format, arguments: args)
    }
    
    public let text: String
}
