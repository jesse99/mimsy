import Cocoa
import MimsyPlugins

class StdHighlightSelection: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerTextView(.closing, closing)
            app.registerTextView(.selectionChanged, selectionChanged)
            app.registerApplyStyle("*", render)
        }
        
        return nil
    }
    
    override func onLoadSettings(_ settings: MimsySettings)
    {
        do
        {
            let text = settings.stringValue("SelectionStyle", missing: "underline=thick")
            styles = try MimsyStyle.parse(app, text)
        }
        catch let err as MimsyError
        {
            app.transcript().write(.error, text: "StdHighlightSelection had an error loading settings: \(err.text)\n")
        }
        catch
        {
            app.transcript().write(.error, text: "StdHighlightSelection unknown error\n")
        }
    }
    
    func closing(_ view: MimsyTextView)
    {
        if let path = view.path
        {
            selections[path] = nil
        }
    }

    // Called whenever the selection changes. We do a quick check to see if the selection
    // range is sane and then stash away the selected word (or nil out the old reference).
    func selectionChanged(_ view: MimsyTextView)
    {
        if let path = view.path, view.language != nil
        {
            var selection: Selection? = nil
            
            let range = view.selectionRange
            if range.length > 0 && range.length < 100
            {
                if isWord(view, range)
                {
                    selection = Selection(word: view.string.substring(with: range), range: range)
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
    func render(_ view: MimsyTextView, styledRange: NSRange)
    {
        if let path = view.path, let selection = selections[path], let storage = view.view.textStorage
        {
            var searchRange = styledRange
            while searchRange.length >= selection.range.length
            {
                let wordRange = view.string.range(of: selection.word, options: .literal, range: searchRange)
                if wordRange.length > 0
                {
                    if isWord(view, wordRange)
                    {
                        MimsyStyle.apply(storage, self.styles, wordRange)
                    }
                    
                    searchRange.location = wordRange.location + wordRange.length
                    searchRange.length = styledRange.location + styledRange.length - searchRange.location
                }
                else
                {
                    searchRange.length = 0
                }
            }
        }
    }
    
    func isWord(_ view: MimsyTextView, _ range: NSRange) -> Bool
    {
        guard let storage = view.view.textStorage else
        {
            return false
        }
        
        // There is a tension between underlining what people are interested in and
        // avoiding cluttering the display. Given that people can always fallback to
        // doing an actual search this script elects to be conservative and only underlines
        // identifiers and identifier-like words.
        let name = storage.getElementName(range)
        return name == "identifier" || name == "function" || name == "define" || name == "macro" || name == "type" || name == "structure" || name == "typedef"
    }
    
    struct Selection
    {
        let word: String
        let range: NSRange
    }
    
    var selections: [MimsyPath: Selection] = [:]
    var styles: [MimsyStyle] = []
}


extension StdHighlightSelection.Selection: Equatable
{
}

func ==(lhs: StdHighlightSelection.Selection, rhs: StdHighlightSelection.Selection) -> Bool
{
    return lhs.word == rhs.word && lhs.range.location == rhs.range.location && lhs.range.length == rhs.range.length
}
