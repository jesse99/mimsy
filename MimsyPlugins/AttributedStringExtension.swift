import Foundation

public extension NSAttributedString
{
    /// If the range was styled using a single element from a language file
    /// then the lower case element name is returned (e.g. "comment"). If not
    /// then nil is returned.
    public func getElementName(_ range: NSRange) -> String?
    {
        var clipRange = NSRange(location: 0, length: 0)
        clipRange.location = range.location > 0 ? range.location - 1 : 0
        clipRange.length = min(range.length + 2, self.length - clipRange.location)
        
        let effRange = UnsafeMutablePointer<NSRange>.allocate(capacity: 1)
        effRange.pointee = NSRange(location: 0, length: 0)
        let attrs = convertFromNSAttributedStringKeyDictionary(self.attributes(at: range.location, longestEffectiveRange: effRange, in: clipRange))
        if let name = attrs["element name"], effRange.pointee.length == range.length
        {
            return (name as! String)
        }

        return nil
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKeyDictionary(_ input: [NSAttributedString.Key: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}
