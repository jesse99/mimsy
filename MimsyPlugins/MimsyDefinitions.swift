import Foundation

public enum ItemName
{
    /// Declarations are things like C function prototypes declared in headers.
    case Declaration(name: String, location: Int)
    
    /// Definitions actually define the name.
    case Definition(name: String, location: Int)
}

public enum ParseMethod: Int
{
    case Regex = 1
    case Parser
    case ExternalTool
}

public protocol ItemParser
{
    var method: ParseMethod {get}

    var globs: MimsyGlob {get}
    
    func parse(path: MimsyPath) throws -> [ItemName]
}

/// Uses registered parsers to parse files within a project. The parsed information
/// is used to generate Goto Declaration and Goto Definition text context menu items.
public protocol MimsyDefinitions
{
    /// Multiple plugins may register themselves. When multiple plugins can parse
    /// a file the plugin with the larger value is used (for ties one plugin is
    /// chosen in an undefined way).
    func register(parser: ItemParser)
}

/// Initialized by (hopefully one) plugin at stage 0.
public var definitions: MimsyDefinitions? = nil
