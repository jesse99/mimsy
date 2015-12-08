import Cocoa
import MimsyPlugins

class StdSelectElement: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        return nil
    }
    
//    # Used by select element when the text document has no language.
//    SelectWordRegex: \b[a-zA-Z]\w*\b
//    
//    # Used by select function when the text document has no language.
//    SelectParaRegex: \n([ \t]*\n)+
    override func onLoadSettings(settings: MimsySettings)
    {
        // TODOL get next element working with plain text
        // TODOL get next function working with plain text
        elementNames = settings.stringValues("SelectElement")
        elementNames = elementNames.map {$0.lowercaseString}
        
        wordRe = compileRe(settings, "SelectWordRegex")
        paraRe = compileRe(settings, "SelectParaRegex")
        
        app.clearRegisterTextViewKey(bundle.bundleIdentifier!)
        app.removeKeyHelp(bundle.bundleIdentifier!, "text editor")
        
        var key = settings.stringValue("SelectNextElementKey", missing: "Option-Tab")
        app.registerTextViewKey(key, bundle.bundleIdentifier!, selectNextElement)
        app.addKeyHelp(bundle.bundleIdentifier!, "text editor", key, "Selects the next identifier.")
        
        key = settings.stringValue("SelectPreviousElementKey", missing: "Option-Shift-Tab")
        app.registerTextViewKey(key, bundle.bundleIdentifier!, selectPreviousElement)
        app.addKeyHelp(bundle.bundleIdentifier!, "text editor", key, "Selects the previous identifier.")
        
        key = settings.stringValue("SelectNextFunctionKey", missing: "Option-Down-Arrow")
        app.registerTextViewKey(key, bundle.bundleIdentifier!, selectNextFunction)
        app.addKeyHelp(bundle.bundleIdentifier!, "text editor", key, "Selects the next function.")
        
        key = settings.stringValue("SelectPreviousFunctionKey", missing: "Option-Up-Arrow")
        app.registerTextViewKey(key, bundle.bundleIdentifier!, selectPreviousFunction)
        app.addKeyHelp(bundle.bundleIdentifier!, "text editor", key, "Selects the previous function.")
    }
    
    func selectNextElement(view: MimsyTextView) -> Bool
    {
        if view.language != nil
        {
            if let text = view.view.textStorage
            {
                var start = view.selectionRange.location + view.selectionRange.length
                var range = NSRange(location: 0, length: 0)
                if let name = text.attribute("element name", atIndex: start, effectiveRange: &range)
                {
                    if range.location < start && self.elementNames.contains(name as! String)
                    {
                        start = range.location + range.length
                    }
                }
                
                let maxRange = NSRange(location: start, length: view.string.length - start)
                let options = NSAttributedStringEnumerationOptions(rawValue: 0)
                text.enumerateAttribute("element name", inRange: maxRange, options: options, usingBlock: { (value, range, stop) -> Void in
                    if let name = value as? NSString
                    {
                        if self.elementNames.contains(name as String)
                        {
                            view.selectionRange = range
                            stop.memory = true
                        }
                    }
                })
            }
        }
        else if let re = wordRe
        {
            let start = view.selectionRange.location + view.selectionRange.length
            let maxRange = NSRange(location: start, length: view.string.length - start)
            let range = re.rangeOfFirstMatchInString(view.text, options: .WithTransparentBounds, range: maxRange)
            if range.length > 0
            {
                view.selectionRange = range
            }
        }
        
        return true
    }
    
    func selectPreviousElement(view: MimsyTextView) -> Bool
    {
        if view.language != nil
        {
            if let text = view.view.textStorage
            {
                var start = view.selectionRange.location
                var range = NSRange(location: 0, length: 0)
                if let name = text.attribute("element name", atIndex: start, effectiveRange: &range)
                {
                    if range.location + range.length < start && self.elementNames.contains(name as! String)
                    {
                        start = range.location
                    }
                }
                
                let maxRange = NSRange(location: 0, length: start)
                let options = NSAttributedStringEnumerationOptions.Reverse
                text.enumerateAttribute("element name", inRange: maxRange, options: options, usingBlock: { (value, range, stop) -> Void in
                    if let name = value as? NSString
                    {
                        if self.elementNames.contains(name as String)
                        {
                            view.selectionRange = range
                            stop.memory = true
                        }
                    }
                })
            }
        }
        else if let re = wordRe
        {
            // Unlike attributes there is no good way to search backwards using a regex so
            // we'll just backup 200 characters which should be fine because we're not dealing
            // with having to skip past long runs of non-words. TODO: Could make the 200 an
            // option, maybe it would matter for very unusual documents like ASCII art.
            let start = view.selectionRange.location
            let loc = max(0, start - 200)
            let maxRange = NSRange(location: loc, length: start - loc)
            let matches = re.matchesInString(view.text, options: .WithTransparentBounds, range: maxRange)
            if !matches.isEmpty
            {
                view.selectionRange = matches[matches.count - 1].range
            }
        }
      
        return true
    }
    
    // TODO: Find the paragraph and then select an element.
    func selectNextFunction(view: MimsyTextView) -> Bool
    {
        if let text = view.view.textStorage
        {
            let start = view.selectionRange.location + view.selectionRange.length
            let maxRange = NSRange(location: start, length: view.string.length - start)
            let options = NSAttributedStringEnumerationOptions(rawValue: 0)
            text.enumerateAttribute("element name", inRange: maxRange, options: options, usingBlock: { (value, range, stop) -> Void in
                if let name = value as? NSString
                {
                    if name == "function"
                    {
                        view.selectionRange = range
                        view.view.scrollRangeToVisible(range)
                        view.view.showFindIndicatorForRange(range)
                        
                        stop.memory = true
                    }
                }
            })
        }
        
        return true
    }
    
    func selectPreviousFunction(view: MimsyTextView) -> Bool
    {
        if let text = view.view.textStorage
        {
            let start = view.selectionRange.location
            let maxRange = NSRange(location: 0, length: start)
            let options = NSAttributedStringEnumerationOptions.Reverse
            text.enumerateAttribute("element name", inRange: maxRange, options: options, usingBlock: { (value, range, stop) -> Void in
                if let name = value as? NSString
                {
                    if name == "function"
                    {
                        view.selectionRange = range
                        view.view.scrollRangeToVisible(range)
                        view.view.showFindIndicatorForRange(range)
                        
                        stop.memory = true
                    }
                }
            })
        }
        
        return true
    }
    
    func compileRe(settings: MimsySettings, _ name: String) -> NSRegularExpression?
    {
        var re: NSRegularExpression? = nil
        
        let pattern = settings.stringValue(name, missing: "")
        do
        {
            if !pattern.isEmpty
            {
                re = try NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions(rawValue: 0))
            }
        }
        catch let error as NSError
        {
            app.log("Plugins", "%@ is '%@' which isn't a valid regex: %@", name, pattern, error.localizedFailureReason!)
        }
        catch
        {
            app.log("Plugins", "%@ is '%@' which isn't a valid regex", name, pattern)
        }
        
        return re
    }
    
    var elementNames: [String] = []
    var wordRe: NSRegularExpression? = nil
    var paraRe: NSRegularExpression? = nil
}
