import Cocoa

/// Contains information about the language a text view is using.
@objc public protocol MimsyLanguage
{
    /// The language name, "python", "objc", "go", etc.
    var name: String {get}
    
    /// Contains settings for only the language.
    var settings: MimsySettings {get}
    
    /// Text used for comments extending to the end of a line, e.g. "//".
    var lineComment: String? {get}
    
    /// Used to match identifiers within the language.
    var word: NSRegularExpression? {get}
    
    /// Used to match integral and floating point literals within the language.
    var number: NSRegularExpression? {get}
    
    /// Returns true if the file's extension matches the languages extensions
    /// or the file has a matching shebang.
    func matches(file: MimsyPath) -> Bool
    
    /// Returns the regular expression patterns associated with the element.
    /// Note that zero or more patterns may be returned.
    func getPatterns(element: String) -> [String]
}
