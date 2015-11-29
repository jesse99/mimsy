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
    /// - Parameter undoText: Text added to the Undo menu item. If nil then the replacement is not undoable.
    func setSelection(text: String, undoText: String?)
    
    /// Returns a reference to the view's text.
    var text: String {get}
    
    /// Replaces all of the text within the document.
    ///
    /// - Parameter text: The new text.
    /// - Parameter undoText: Text added to the Undo menu item. If nil then the replacement is not undoable.
    func setText(text: String, undoText: String?)
}
