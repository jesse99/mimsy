import Cocoa

@objc public enum MappingOptions: Int
{
    /// The mappings glyphs are rendered for each character that was matched.
    case useGlyphsForEachChar = 0
    
    /// The mappings glyphs are rendered for the entire match.
    case useGlyphsForEntireRange
}

/// Helper used to communicate with Mimsy's text document views.
@objc public protocol MimsyTextView
{
    /// Contains settings for the language (if any) the project and the app but not for the 
    /// current plugin.
    var settings: MimsySettings {get}
    
   /// Language objects are used to style the text (e.g. to render keywords using bold) and
    /// to customize bits of behavior (e.g. to allow double-clicking to select identifiers
    /// in languages that allow unusual characters in identifiers). If there is no language
    /// then the document is a rich text document and styles must all be manually applied.
    var language: MimsyLanguage? {get}

    /// Gets or sets the range of the current selection.
    var selectionRange: NSRange {get set}

    /// Gets the text within the current selection. Use replaceText:undoText:
    /// to set the text.
    var selection: String {get}
    
    /// Replaces the text within the current selection.
    ///
    /// - Parameter text: The text used for the selection.
    /// - Parameter undoText: Text added to the Undo menu item.
    func setSelection(_ text: String, undoText: String)
    
    /// Returns the project the text document is within, if any.
    var project: MimsyProject? {get}

    var view: NSTextView {get}

    /// Returns a reference to the view's text. Note that text documents are always Unix
    /// line endian while in memory.
    var text: String {get}
    
    /// Returns a reference to the view's text. This is provided for plugins that need
    /// random access to characters which is much easier to do with NSString than String.
    var string: NSString {get}

    /// Returns the full path to the associated document or nil if it hasn't been saved yet.
    var path: MimsyPath? {get}
    
    /// Replaces all of the text within the document.
    ///
    /// - Parameter text: The new text.
    /// - Parameter undoText: Text added to the Undo menu item.
    func setText(_ text: String, undoText: String)
    
    /// Replaces part of the text within the document.
    ///
    /// - Parameter text: The new text.
    /// - Parameter forRange: The range to replace with the new text.
    /// - Parameter undoText: Text added to the Undo menu item.
    func setText(_ text: String, forRange: NSRange, undoText: String)

    /// Mappings are used to modify the way that text is rendered after language styles are applied.
    /// If a mapping with the regex already exists then the old mapping will be replaced with the
    /// new settings.
    ///
    /// - Parameter regex: The regular expression to use when matching ranges to the styled text,
    /// - Parameter style: The style to use with the glyphs, e.g. "Normal" or "Error".
    /// - Parameter chars: Characters to render the matched text with. Often a special Unicode character
    /// like "\u2738" (HEAVY EIGHT POINTED RECTILINEAR BLACK STAR).
    /// - Parameter options: Whether to use the glyphs for the entire match or for each character within the match.
    func addMapping(_ regex: NSRegularExpression, style: String, chars: String, options: MappingOptions)
    
    /// Removes a mapping added with addMapiing. No-op if the regex cannot be found.
    ///
    /// - Parameter regex: Must be identical to the object passed into addMapping.
    func removeMapping(_ regex: NSRegularExpression)
    
    /// Forces language styling to be re-applied.
    func resetStyles()
}

public extension MimsyTextView
{
    /// Returns the range of the lines the selection is within, including the
    /// trailing new lines.
    public func selectedLineRange() -> NSRange
    {
        let text = string
        
        var start = selectionRange.location
        var end = selectionRange.location + max(selectionRange.length, 1)
        
        // Go backwards till the start of the line.
        while start > 0
        {
            let ch = text.character(at: start-1)
            if ch == 10
            {
                break
            }
            start -= 1
        }
        
        // Go forward till the end of the line.
        while end < text.length
        {
            let ch = text.character(at: end - 1)
            if ch == 10
            {
                break
            }
            end += 1
        }
        
        return NSRange(location: start, length: end - start)
    }
}
