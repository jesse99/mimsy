import Foundation

public extension NSAttributedString
{
    /// If the range was styled using a single element from a language file
    /// then the lower case element name is returned (e.g. "comment"). If not
    /// then nil is returned.
    public func getElementName(range: NSRange) -> String?
    {
        var clipRange = NSRange(location: 0, length: 0)
        clipRange.location = range.location > 0 ? range.location - 1 : 0
        clipRange.length = min(range.length + 2, self.length - clipRange.location)
        
        let effRange = UnsafeMutablePointer<NSRange>.alloc(1)
        effRange.memory = NSRange(location: 0, length: 0)
        let attrs = self.attributesAtIndex(range.location, longestEffectiveRange: effRange, inRange: clipRange)
        if let name = attrs["element name"] where effRange.memory.length == range.length
        {
            return (name as! String)
        }

        return nil
    }
}