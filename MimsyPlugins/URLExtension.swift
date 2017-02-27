import Foundation

public extension URL
{
    /// Wrapper around getResourceValue(NSURLContentModificationDateKey).
    public func contentModificationDateValue() throws -> Date
    {
        var rsrc: AnyObject?
        try (self as NSURL).getResourceValue(&rsrc, forKey: URLResourceKey.contentModificationDateKey)
        if let date = rsrc as? Date
        {
            return date
        }
        throw MimsyError("NSURLContentModificationDateKey resource isn't an NSDate")
    }

    /// Wrapper around getResourceValue(NSURLIsDirectoryKey).
    public func isDirectoryValue() throws -> Bool
    {
        var rsrc: AnyObject?
        try (self as NSURL).getResourceValue(&rsrc, forKey: URLResourceKey.isDirectoryKey)
        if let flag = rsrc as? NSNumber
        {
            return flag == 1
        }
        return false
    }
    
    /// Wrapper around getResourceValue(NSURLNameKey).
    public func nameValue() throws -> String
    {
        var rsrc: AnyObject?
        try (self as NSURL).getResourceValue(&rsrc, forKey: URLResourceKey.nameKey)
        if let name = rsrc as? NSString
        {
            return name as String
        }
        throw MimsyError("NSURLNameKey resource isn't an NSString")
    }
    
    /// Wrapper around getResourceValue(NSURLPathKey).
    public func pathValue() throws -> MimsyPath
    {
        var rsrc: AnyObject?
        try (self as NSURL).getResourceValue(&rsrc, forKey: URLResourceKey.pathKey)
        if let path = rsrc as? NSString
        {
            return MimsyPath(withString: path as String)
        }
        throw MimsyError("NSURLPathKey resource isn't an NSString")
    }
}

