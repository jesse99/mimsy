import Foundation

public extension String
{
    /// Takes a path to a file or directory and returns a new path
    /// suitable for humans that does not point to a file or directory.
    public func stringByFindingUniquePath() -> String
    {
        let str = self as NSString
        let root = str.stringByDeletingPathExtension
        let ext = str.pathExtension
        
        var n = 1
        let fm = NSFileManager.defaultManager()
        while true
        {
            let candidate = "\(root) \(n).\(ext)"
            if !fm.fileExistsAtPath(candidate)  // also checks for directories
            {
                return candidate
            }
            n++
        }
    }
}