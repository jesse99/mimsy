import Foundation

public struct MimsyError: ErrorType
{
    public init(_ format: String, _ args: CVarArgType...)
    {
        text = String(format: format, arguments: args)
    }
    
    public let text: String
}
