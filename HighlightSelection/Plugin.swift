import Cocoa
import MimsyPlugins

class StdHighlightSelection: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerTextView(.Closing, closing)
            app.registerTextView(.SelectionChanged, selectionChanged)
            app.registerApplyStyle("*", render)
        }
        
        return nil
    }
    
    override func onLoadSettings(settings: MimsySettings)
    {
//        var words = settings.stringValues("TodoWord")
//        words = words.map {"(" + $0 + ")"}
//        let pattern = words.joinWithSeparator("|")
//        
//        do
//        {
//            re = try NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions(rawValue: 0))
//        }
//        catch let err as NSError
//        {
//            app.transcript().write(.Error, text: "StdHighlightTodo couldn't compile '\(pattern)' as a regex: \(err.localizedFailureReason)")
//        }
//        catch
//        {
//            app.transcript().write(.Error, text: "StdHighlightTodo unknown error compiling '\(pattern)' as a regex")
//        }
//        
//        // This doesn't provide much customization for users but the standard route of extracting
//        // styles from an rtf setting file will be awkward because blowing away the existing comment
//        // styling isn't composable. TODO: could use a setting with attribute name/value pairs.
//        weight = settings.floatValue("TodoWeight", missing: 5.0)
    }
    
    func closing(view: MimsyTextView)
    {
        if let path = view.path as? String
        {
            selections[path] = nil
        }
    }

    // Called whenever the selection changes. We do a quick check to see if the selection
    // range is sane and then stash away the selected word (or nil out the old reference).
    func selectionChanged(view: MimsyTextView)
    {
        if let path = view.path as? String where view.language != nil
        {
            var selection: Selection? = nil
            
            let range = view.selectionRange
            if range.length > 0 && range.length < 100
            {
                if isWord(view, range)
                {
                    selection = Selection(word: view.string.substringWithRange(range), range: range)
                }
            }
            
            if selection != selections[path]
            {
                selections[path] = selection
                
                // We need to reset any underlining that may have been present
                // and start styling the text again to apply any underling we may
                // now have.
                view.resetStyles()
            }
        }
    }
    
    // This is called after styles have been applied to a chunk of text. We find all the
    // instances of the word in the chunk and underline them if they are not the original
    // selection and not substrings of a larger identifier.
    func render(view: MimsyTextView, styledRange: NSRange)
    {
        if let path = view.path as? String, let selection = selections[path], let storage = view.view.textStorage
        {
            var searchRange = styledRange
            while searchRange.length >= selection.range.length
            {
                let wordRange = view.string.rangeOfString(selection.word, options: .LiteralSearch, range: searchRange)
                if wordRange.length > 0
                {
                    if isWord(view, wordRange)
                    {
                        storage.addAttribute(NSUnderlineStyleAttributeName, value: NSNumber(integer:NSUnderlineStyle.StyleThick.rawValue), range: wordRange)
                    }
                    
                    searchRange.location = wordRange.location + wordRange.length
                    searchRange.length = styledRange.length - searchRange.location
                }
                else
                {
                    searchRange.length = 0
                }
            }
        }
    }
    
    func isWord(view: MimsyTextView, _ range: NSRange) -> Bool
    {
        // There is a tension between underlining what people are interested in and
        // avoiding cluttering the display. Given that people can always fallback to
        // doing an actual search this script elects to be conservative and only underlines
        // identifiers and identifier-like words.
        guard let storage = view.view.textStorage else
        {
            return false
        }
        
        let name = storage.getElementName(range)
        return name == "identifier" || name == "function" || name == "define" || name == "macro" || name == "type" || name == "structure" || name == "typedef"
    }
    
    struct Selection
    {
        let word: String
        let range: NSRange
    }
    
    var selections: [String: Selection] = [:]
}


extension StdHighlightSelection.Selection: Equatable
{
}

func ==(lhs: StdHighlightSelection.Selection, rhs: StdHighlightSelection.Selection) -> Bool
{
    return lhs.word == rhs.word && lhs.range.location == rhs.range.location && lhs.range.length == rhs.range.length
}
