import Cocoa

/// Helper used to communicate with Mimsy's text document views.
@objc public protocol MimsyTextView
{
    /// Gets or sets the range of the current selection.
    var selectionRange: NSRange {get set}

    /// Gets the text within the current selection. Use replaceText:undoText:
    /// to set the text.
    var selection: String {get}
    
    /// Returns a reference to the view's text (this doesn't use String because String
    /// is a value type and the text may be quite large).
    var text: NSString {get}
    
    /// Replaces the text within the current selection.
    ///
    /// - Parameter text: The text used for the selection.
    /// - Parameter undoText: Text added to the Undo menu item. If nil then the replacement is not undoable.
    func replaceText(text: String, undoText: String?)
}
