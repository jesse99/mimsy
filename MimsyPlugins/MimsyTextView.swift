import Cocoa

/// Helper used to communicate with Mimsy's text document views.
@objc public protocol MimsyTextView
{
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
    func setSelection(text: String, undoText: String)
    
    /// Returns a reference to the view's text. Note that text documents are always Unix
    /// line endian while in memory.
    var text: String {get}
    
    /// Returns a reference to the view's text. This is provided for plugins that need
    /// random access to characters which is much easier to do with NSString than String.
    var string: NSString {get}
    
    /// Replaces all of the text within the document.
    ///
    /// - Parameter text: The new text.
    /// - Parameter undoText: Text added to the Undo menu item.
    func setText(text: String, undoText: String)
    
    /// Replaces part of the text within the document.
    ///
    /// - Parameter text: The new text.
    /// - Parameter forRange: The range to replace with the new text.
    /// - Parameter undoText: Text added to the Undo menu item.
    func setText(text: String, forRange: NSRange, undoText: String)
}

public extension MimsyTextView
{
    /// Returns the contents of the lines that intersect the selection along with
    /// the range of those lines.
    public func selectionLines() -> (String, NSRange)
    {
        let text = string
        
        var start = selectionRange.location
        var end = selectionRange.location + selectionRange.length
        
        // Go backwards till the start of the line.
        while start > 0
        {
            let ch = text.characterAtIndex(start-1)
            if ch == 10
            {
                break
            }
            start -= 1
        }
        
        //                                          01
        // Go forward till the end of the line.     X\n
        while end < text.length
        {
            let ch = text.characterAtIndex(end - 1)
            if ch == 10
            {
                break
            }
            end += 1
        }
        
        let range = NSRange(location: start, length: end - start)
        let lines = text.substringWithRange(range)
        return (lines, range)
    }
}
