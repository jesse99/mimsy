import Foundation

/// Type safe path abstraction.
public class MimsyPath: NSObject, CustomDebugStringConvertible
{
    /// Constructs a path without attempting to standardize the path.
    public init(withString: String)
    {
        assert(!withString.isEmpty)
 
        path = withString
        super.init()
    }
    
    /// Constructs a path by concatenating the components with the path separator.
    /// Note that this does not standardize the path. To create an absolute
    /// path use "/" as the first component.
    public init(withComponents: String...)
    {
        path = NSString.pathWithComponents(withComponents)
        super.init()
        
        assert(path.length > 0)
    }
    
    public init(withArray: [String])
    {
        path = NSString.pathWithComponents(withArray)
        super.init()
        
        assert(path.length > 0)
    }
    
    public override var debugDescription: String
    {
        get {return path as String}
    }

    override public var description: String
    {
        return path as String
    }
    
    public override func isEqual(object: AnyObject?) -> Bool
    {
        if let rhs = object as? MimsyPath
        {
            return path.isEqualToString(rhs.path as String)
        }
        return false
    }
    
    public override var hash: Int
    {
        return path.hash
    }
    
    public func isEqualTo(path path: MimsyPath?) -> Bool
    {
        return path != nil && self.path.isEqualToString(path!.path as String)
    }
    
    /// This should only be used for interop.
    public func asString() -> String
    {
        return path as String
    }
    
    /// This should only be used for interop.
    public func asURL() -> NSURL
    {
        return NSURL(fileURLWithPath: path as String)
    }
    
    /// Cleans up the path by:
    /// * Expanding an initial tilde/
    /// * Removing trailing slashes.
    /// * For absolute paths resolving "..".
    /// * Reducing things like "//" and "/./" to a single slash.
    /// Note that symbolic links are not resolved.
    public func standardize() -> MimsyPath
    {
        return MimsyPath(withString: path.stringByStandardizingPath)
    }
    
    /// Resolves all sym links in absolute paths and as many as possible
    /// for relative paths then standardize the result.
    public func resolveSymLinks() -> MimsyPath
    {
        return MimsyPath(withString: path.stringByResolvingSymlinksInPath)
    }
    
    /// Returns a new path suitable for humans that does not point to an 
    /// existing file or directory.
    public func makeUnique() -> MimsyPath
    {
        let root = self.popExtension()
        let ext = self.hasExtension() ? ".\(self.extensionName())" : ""
        
        var n = 0
        let fm = NSFileManager.defaultManager()
        while true
        {
            let candidate = n == 0 ? "\(root)\(ext)" : "\(root) \(n)\(ext)"
            if !fm.fileExistsAtPath(candidate)  // also checks for directories
            {
                return MimsyPath(withString: candidate)
            }
            n++
        }
    }
    
    /// Returns true if the path is an absolute path.
    public func isAbsolute() -> Bool
    {
        return path.absolutePath
    }

    /// Returns true if the last component has a period.
    public func hasExtension() -> Bool
    {
        return self.extensionName() != nil
    }
    
    /// Returns the modification time in seconds. For a directory this will
    /// return the last time a file within the directory was added, removed
    /// or renamed (but not modified).
    public func modTime() throws -> Double
    {
        return try app!._modTime(self).doubleValue
    }
    
    /// Returns true if the target's components start with all the roots components.
    public func hasRoot(root: MimsyPath) -> Bool
    {
        let lhs = self.components()
        let rhs = root.components()
        return lhs.count >= rhs.count && lhs.prefix(rhs.count) == ArraySlice(rhs)
    }
    
    /// Returns true if the target's components end with all the stems components.
    public func hasStem(stem: MimsyPath) -> Bool
    {
        let lhs = self.components()
        let rhs = stem.components()
        return lhs.count >= rhs.count && lhs.suffix(rhs.count) == ArraySlice(rhs)
    }
    
    /// Removes the root's components from the start of the target.
    /// Error if hasRoot is false.
    public func removeRoot(root: MimsyPath) -> MimsyPath
    {
        assert(hasRoot(root))
        
        let lhs = self.components()
        let rhs = root.components()
        let components = lhs.suffix(lhs.count - rhs.count)
        return MimsyPath(withArray: Array(components))
    }
    
    /// For "foo/bar.rtf" this will return ["foo", "bar.rtf"].
    /// For "/foo/bar.rtf" this will return ["/", "foo", "bar.rtf"].
    public func components() -> [String]
    {
        return path.pathComponents
    }
    
    /// For "/tmp/scratch.tiff" this returns "scratch.tiff".
    /// For "/tmp/scratch" this returns "scratch".
    /// For "/tmp/" this returns "tmp".
    /// For "scratch///" this returns "scratch".
    /// For "/" this returns "/".
    public func lastComponent() -> String
    {
        return path.lastPathComponent
    }
    
    /// Returns the portion of the path after the last period or
    /// nil if the lastComponent has no period.
    public func extensionName() -> String?
    {
        let name = path.pathExtension
        return name.isEmpty ? nil : name
    }
    
    /// Creates a new path by appending a relative path onto the target.
    public func append(path path: MimsyPath) -> MimsyPath
    {
        assert(!path.isAbsolute())
        
        let lhs = self.components()
        let rhs = path.components()
        return MimsyPath(withArray: lhs+rhs)
    }
    
    /// Creates a new path by appending a new path component onto the target.
    public func append(component component: String) -> MimsyPath
    {
        return MimsyPath(withString: path.stringByAppendingPathComponent(component))
    }
    
    /// Creates a new path by appending an extension onto the target (don't include the period).
    public func append(extensionName extensionName: String) -> MimsyPath
    {
        assert(!extensionName.hasPrefix("."))
        return MimsyPath(withString: path.stringByAppendingPathExtension(extensionName)!)
    }
    
    /// Removes the last component along with a trailing slash (if present).
    public func popComponent() -> MimsyPath
    {
        return MimsyPath(withString: path.stringByDeletingLastPathComponent)
    }
    
    /// Removes the extension name and period (if present).
    public func popExtension() -> MimsyPath
    {
        return MimsyPath(withString: path.stringByDeletingPathExtension)
    }
    
    let path: NSString
}