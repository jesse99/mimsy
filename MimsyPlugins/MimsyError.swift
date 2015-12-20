import Foundation

public struct MimsyError: ErrorType
{
    init(_ format: String, _ args: CVarArgType...)
    {
        text = String(format: format, arguments: args)
    }
    
    public let text: String
}
