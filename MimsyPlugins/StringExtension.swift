import Foundation

public extension String
{
    /// Takes a path to a file or directory and returns a new path
    /// suitable for humans that does not point to an existing file
    /// or directory.
    public func stringByFindingUniquePath() -> String
    {
        let str = self as NSString
        let root = str.stringByDeletingPathExtension
        let ext = str.pathExtension.isEmpty ? "" : ".\(str.pathExtension)"
        
        var n = 0
        let fm = NSFileManager.defaultManager()
        while true
        {
            let candidate = n == 0 ? "\(root)\(ext)" : "\(root) \(n)\(ext)"
            if !fm.fileExistsAtPath(candidate)  // also checks for directories
            {
                return candidate
            }
            n++
        }
    }
}