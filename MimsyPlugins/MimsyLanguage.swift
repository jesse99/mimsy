import Cocoa

/// Contains information about the language a text view is using.
@objc public protocol MimsyLanguage
{
    /// The language name, "python", "objc", "go", etc.
    var name: String {get}
    
    /// Text used for comments extending to the end of a line, e.g. "//".
    var lineComment: String? {get}
    
    /// Used to match identifiers within the language.
    var word: NSRegularExpression? {get}
    
    /// Used to match integral and floating point literals within the language.
    var number: NSRegularExpression? {get}
}
