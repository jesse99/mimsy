import Foundation

public enum ParseMethod: Int
{
    case Regex = 1
    case Parser
    case ExternalTool
}

public enum ItemName
{
    /// Declarations are things like C function prototypes declared in headers.
    case Declaration(name: String, location: Int)
    
    /// Definitions actually define the name.
    case Definition(name: String, location: Int)
}

public struct ItemPath
{
    public init(path: MimsyPath, location: Int)
    {
        self.path = path
        self.location = location
    }
    
    public let path: MimsyPath
    
    public let location: Int
}

public protocol ItemParser
{
    var method: ParseMethod {get}
    
    /// Returns a value if the parser was capable of parsing the file.
    /// Throws if there was an error parsing (typically a file IO error,
    /// syntax problems should be ignored). Note that this is typically
    /// called from a thread.
    func tryParse(path: MimsyPath) throws -> [ItemName]?
}

/// Uses registered parsers to parse files within a project. The parsed information
/// is used to generate Goto Declaration and Goto Definition text context menu items.
public protocol MimsyDefinitions
{
    /// Multiple plugins may register themselves. When multiple plugins can parse
    /// a file the plugin with the larger value is used (for ties one plugin is
    /// chosen in an undefined way).
    func register(parser: ItemParser)
    
    /// Returns zero or more paths to declarations for a name.
    func declarations(project: MimsyProject, name: String) -> [ItemPath]
    
    /// Returns zero or more paths to declarations for a name.
    func definitions(project: MimsyProject, name: String) -> [ItemPath]
}

/// Initialized by (hopefully one) plugin at stage 0.
public var definitionsPlugin: MimsyDefinitions? = nil

