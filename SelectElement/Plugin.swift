import Cocoa
import MimsyPlugins

class StdSelectElement: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        return nil
    }
    
    override func onLoadSettings(settings: MimsySettings)
    {
        // TODO: use  and
        // TODOL get next element working with plain text
        // TODOL get next function working with plain text
        elementNames = settings.stringValues("SelectElement")
        elementNames = elementNames.map {$0.lowercaseString}
        
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
        
        return true
    }
    
    func selectPreviousElement(view: MimsyTextView) -> Bool
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
        
        return true
    }
    
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
    
    var elementNames: [String] = []
}
