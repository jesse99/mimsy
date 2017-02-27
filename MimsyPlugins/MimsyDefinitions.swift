import Foundation

public enum ParseMethod: Int
{
    case regex = 1
    case parser
    case externalTool
}

public enum ItemName
{
    /// Declarations are things like C function prototypes declared in headers.
    case declaration(name: String, location: Int)
    
    /// Definitions actually define the name.
    case definition(name: String, location: Int)
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
    
    /// Returns the file name extensions that the plugin can handle.
    /// Note that these do not include the dot.
    var extensionNames: [String] {get}
    
    /// Throws if there was an error parsing (typically a file IO error,
    /// syntax problems should be ignored). Note that this is typically
    /// called from a thread.
    func parse(_ path: MimsyPath) throws -> [ItemName]
}

/// Uses registered parsers to parse files within a project. The parsed information
/// is used to generate Goto Declaration and Goto Definition text context menu items.
public protocol MimsyDefinitions
{
    /// Multiple plugins may register themselves. When multiple plugins can parse
    /// a file the plugin with the larger value is used (for ties one plugin is
    /// chosen in an undefined way).
    func register(_ parser: ItemParser)
    
    /// Returns zero or more paths to declarations for a name.
    func declarations(_ project: MimsyProject, name: String) -> [ItemPath]
    
    /// Returns zero or more paths to declarations for a name.
    func definitions(_ project: MimsyProject, name: String) -> [ItemPath]
}

/// Initialized by (hopefully one) plugin at stage 0.
public var definitionsPlugin: MimsyDefinitions? = nil

