import Cocoa
import MimsyPlugins

class StdSelectElement: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        return nil
    }
    
    override func onLoadSettings(_ settings: MimsySettings)
    {
        elementNames = settings.stringValues("SelectElement")
        elementNames = elementNames.map {$0.lowercased()}
        
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
    
    func selectNextElement(_ view: MimsyTextView) -> Bool
    {
        if view.language != nil
        {
            if let text = view.view.textStorage
            {
                var start = view.selectionRange.location + view.selectionRange.length
                var range = NSRange(location: 0, length: 0)
                if let name = text.attribute(convertToNSAttributedStringKey("element name"), at: start, effectiveRange: &range)
                {
                    if range.location < start && self.elementNames.contains(name as! String)
                    {
                        start = range.location + range.length
                    }
                }
                
                let maxRange = NSRange(location: start, length: view.string.length - start)
                let options = NSAttributedString.EnumerationOptions(rawValue: 0)
                text.enumerateAttribute(convertToNSAttributedStringKey("element name"), in: maxRange, options: options, using: { (value, range, stop) -> Void in
                    if let name = value as? NSString
                    {
                        if self.elementNames.contains(name as String)
                        {
                            view.selectionRange = range
                            stop.pointee = true
                        }
                    }
                })
            }
        }
        else if let re = wordRe
        {
            let start = view.selectionRange.location + view.selectionRange.length
            let maxRange = NSRange(location: start, length: view.string.length - start)
            let range = re.rangeOfFirstMatch(in: view.text, options: .withTransparentBounds, range: maxRange)
            if range.length > 0
            {
                view.selectionRange = range
            }
        }
        
        return true
    }
    
    func selectPreviousElement(_ view: MimsyTextView) -> Bool
    {
        if view.language != nil
        {
            if let text = view.view.textStorage
            {
                var start = view.selectionRange.location
                var range = NSRange(location: 0, length: 0)
                if let name = text.attribute(convertToNSAttributedStringKey("element name"), at: start, effectiveRange: &range)
                {
                    if range.location + range.length < start && self.elementNames.contains(name as! String)
                    {
                        start = range.location
                    }
                }
                
                let maxRange = NSRange(location: 0, length: start)
                let options = NSAttributedString.EnumerationOptions.reverse
                text.enumerateAttribute(convertToNSAttributedStringKey("element name"), in: maxRange, options: options, using: { (value, range, stop) -> Void in
                    if let name = value as? NSString
                    {
                        if self.elementNames.contains(name as String)
                        {
                            view.selectionRange = range
                            stop.pointee = true
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
            let matches = re.matches(in: view.text, options: .withTransparentBounds, range: maxRange)
            if !matches.isEmpty
            {
                view.selectionRange = matches[matches.count - 1].range
            }
        }
      
        return true
    }
    
    func selectNextFunction(_ view: MimsyTextView) -> Bool
    {
        if view.language != nil
        {
            if let text = view.view.textStorage
            {
                let start = view.selectionRange.location + view.selectionRange.length
                let maxRange = NSRange(location: start, length: view.string.length - start)
                let options = NSAttributedString.EnumerationOptions(rawValue: 0)
                text.enumerateAttribute(convertToNSAttributedStringKey("element name"), in: maxRange, options: options, using: { (value, range, stop) -> Void in
                    if let name = value as? NSString
                    {
                        if name == "function"
                        {
                            view.selectionRange = range
                            view.view.scrollRangeToVisible(range)
                            view.view.showFindIndicator(for: range)
                            
                            stop.pointee = true
                        }
                    }
                })
            }
        }
        else if let re = paraRe
        {
            let start = view.selectionRange.location + view.selectionRange.length
            let maxRange = NSRange(location: start, length: view.string.length - start)
            let range = re.rangeOfFirstMatch(in: view.text, options: .withTransparentBounds, range: maxRange)
            if range.length > 0
            {
                view.selectionRange = range
                _ = selectNextElement(view)

                view.view.scrollRangeToVisible(view.selectionRange)
                view.view.showFindIndicator(for: view.selectionRange)
            }
        }
       
        return true
    }
    
    func selectPreviousFunction(_ view: MimsyTextView) -> Bool
    {
        if view.language != nil
        {
            if let text = view.view.textStorage
            {
                let start = view.selectionRange.location
                let maxRange = NSRange(location: 0, length: start)
                let options = NSAttributedString.EnumerationOptions.reverse
                text.enumerateAttribute(convertToNSAttributedStringKey("element name"), in: maxRange, options: options, using: { (value, range, stop) -> Void in
                    if let name = value as? NSString
                    {
                        if name == "function"
                        {
                            view.selectionRange = range
                            view.view.scrollRangeToVisible(range)
                            view.view.showFindIndicator(for: range)
                            
                            stop.pointee = true
                        }
                    }
                })
            }
        }
        else if let re = paraRe
        {
            let start = view.selectionRange.location
            let loc = max(0, start - 10_000)
            let maxRange = NSRange(location: loc, length: start - loc)
            let matches = re.matches(in: view.text, options: .withTransparentBounds, range: maxRange)
            
            var found = false
            if !matches.isEmpty
            {
                // Find the line break starting the current paragraph.
                var i = 0
                while i+1 < matches.count && matches[i+1].range.location < start
                {
                    i += 1
                }

                // Select the line break before that.
                if i > 0 && matches[i-1].range.location < start
                {
                    view.selectionRange = matches[i-1].range
                    found = true
                }
            }
            
            if !found
            {
                view.selectionRange = NSRange(location: 0, length: 0)
            }
            
            _ = selectNextElement(view)
            view.view.scrollRangeToVisible(view.selectionRange)
            view.view.showFindIndicator(for: view.selectionRange)
        }
       
        return true
    }
    
    func compileRe(_ settings: MimsySettings, _ name: String) -> NSRegularExpression?
    {
        var re: NSRegularExpression? = nil
        
        let pattern = settings.stringValue(name, missing: "")
        do
        {
            if !pattern.isEmpty
            {
                re = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options(rawValue: 0))
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

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSAttributedStringKey(_ input: String) -> NSAttributedString.Key {
	return NSAttributedString.Key(rawValue: input)
}
