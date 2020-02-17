import Foundation

/// Type safe path abstraction.
open class MimsyPath: NSObject
{
    /// Constructs a path without attempting to standardize the path.
    @objc public init(withString: String)
    {
        assert(!withString.isEmpty)
 
        path = withString as NSString
        super.init()
    }
    
    /// Constructs a path by concatenating the components with the path separator.
    /// Note that this does not standardize the path. To create an absolute
    /// path use "/" as the first component.
    public init(withComponents: String...)
    {
        path = NSString.path(withComponents: withComponents) as NSString
        super.init()
        
        assert(path.length > 0)
    }
    
    @objc public init(withArray: [String])
    {
        path = NSString.path(withComponents: withArray) as NSString
        super.init()
        
        assert(path.length > 0)
    }
    
    open override var debugDescription: String
    {
        get {return path as String}
    }

    override open var description: String
    {
        return path as String
    }
    
    open override func isEqual(_ object: Any?) -> Bool
    {
        if let rhs = object as? MimsyPath
        {
            return path.isEqual(to: rhs.path as String)
        }
        return false
    }
    
    open override var hash: Int
    {
        return path.hash
    }
    
    @objc open func isEqualTo(path: MimsyPath?) -> Bool
    {
        return path != nil && self.path.isEqual(to: path!.path as String)
    }
    
    /// This should only be used for interop.
    @objc open func asString() -> String
    {
        return path as String
    }
    
    /// This should only be used for interop.
    @objc open func asURL() -> URL
    {
        return URL(fileURLWithPath: path as String)
    }
    
    /// Cleans up the path by:
    /// * Expanding an initial tilde/
    /// * Removing trailing slashes.
    /// * For absolute paths resolving "..".
    /// * Reducing things like "//" and "/./" to a single slash.
    /// Note that symbolic links are not resolved.
    @objc open func standardize() -> MimsyPath
    {
        return MimsyPath(withString: path.standardizingPath)
    }
    
    /// Resolves all sym links in absolute paths and as many as possible
    /// for relative paths then standardize the result.
    @objc open func resolveSymLinks() -> MimsyPath
    {
        return MimsyPath(withString: path.resolvingSymlinksInPath)
    }
    
    /// Returns a new path suitable for humans that does not point to an 
    /// existing file or directory.
    @objc open func makeUnique() -> MimsyPath
    {
        let root = self.popExtension()
        let ext = self.hasExtension() ? ".\(String(describing: self.extensionName()))" : ""
        
        var n = 0
        let fm = FileManager.default
        while true
        {
            let candidate = n == 0 ? "\(root)\(ext)" : "\(root) \(n)\(ext)"
            if !fm.fileExists(atPath: candidate)  // also checks for directories
            {
                return MimsyPath(withString: candidate)
            }
            n += 1
        }
    }
    
    /// Returns true if the path is an absolute path.
    @objc open func isAbsolute() -> Bool
    {
        return path.isAbsolutePath
    }

    /// Returns true if the last component has a period.
    @objc open func hasExtension() -> Bool
    {
        return self.extensionName() != nil
    }
    
    /// Returns the modification time in seconds. For a directory this will
    /// return the last time a file within the directory was added, removed
    /// or renamed (but not modified).
    open func modTime() throws -> Double
    {
        return try app!._modTime(self).doubleValue
    }
    
    /// Returns true if the target's components start with all the roots components.
    @objc open func hasRoot(_ root: MimsyPath) -> Bool
    {
        let lhs = self.components()
        let rhs = root.components()
        return lhs.count >= rhs.count && lhs.prefix(rhs.count) == ArraySlice(rhs)
    }
    
    /// Returns true if the target's components end with all the stems components.
    @objc open func hasStem(_ stem: MimsyPath) -> Bool
    {
        let lhs = self.components()
        let rhs = stem.components()
        return lhs.count >= rhs.count && lhs.suffix(rhs.count) == ArraySlice(rhs)
    }
    
    /// Removes the root's components from the start of the target.
    /// Error if hasRoot is false.
    @objc open func removeRoot(_ root: MimsyPath) -> MimsyPath
    {
        assert(hasRoot(root))
        
        let lhs = self.components()
        let rhs = root.components()
        let components = lhs.suffix(lhs.count - rhs.count)
        return MimsyPath(withArray: Array(components))
    }
    
    /// For "foo/bar.rtf" this will return ["foo", "bar.rtf"].
    /// For "/foo/bar.rtf" this will return ["/", "foo", "bar.rtf"].
    @objc open func components() -> [String]
    {
        return path.pathComponents
    }
    
    /// For "/tmp/scratch.tiff" this returns "scratch.tiff".
    /// For "/tmp/scratch" this returns "scratch".
    /// For "/tmp/" this returns "tmp".
    /// For "scratch///" this returns "scratch".
    /// For "/" this returns "/".
    @objc open func lastComponent() -> String
    {
        return path.lastPathComponent
    }
    
    /// Returns the portion of the path after the last period or
    /// nil if the lastComponent has no period.
    @objc open func extensionName() -> String?
    {
        let name = path.pathExtension
        return name.isEmpty ? nil : name
    }
    
    /// Creates a new path by appending a relative path onto the target.
    @objc open func append(path: MimsyPath) -> MimsyPath
    {
        assert(!path.isAbsolute())
        
        let lhs = self.components()
        let rhs = path.components()
        return MimsyPath(withArray: lhs+rhs)
    }
    
    /// Creates a new path by appending a new path component onto the target.
    @objc open func append(component: String) -> MimsyPath
    {
        return MimsyPath(withString: path.appendingPathComponent(component))
    }
    
    /// Creates a new path by appending an extension onto the target (don't include the period).
    @objc open func append(extensionName: String) -> MimsyPath
    {
        assert(!extensionName.hasPrefix("."))
        return MimsyPath(withString: path.appendingPathExtension(extensionName)!)
    }
    
    /// Removes the last component along with a trailing slash (if present).
    @objc open func popComponent() -> MimsyPath
    {
        return MimsyPath(withString: path.deletingLastPathComponent)
    }
    
    /// Removes the extension name and period (if present).
    @objc open func popExtension() -> MimsyPath
    {
        return MimsyPath(withString: path.deletingPathExtension)
    }
    
    @objc let path: NSString
}
