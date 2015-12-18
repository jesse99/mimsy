import Cocoa
import MimsyPlugins

class StdHighlightTodo: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerApplyStyle("Comment", render)
        }
        
        return nil
    }
    
    override func onLoadSettings(settings: MimsySettings)
    {
        var words = settings.stringValues("TodoWord")
        words = words.map {"(" + $0 + ")"}
        let pattern = words.joinWithSeparator("|")
        
        do
        {
            re = try NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions(rawValue: 0))
        }
        catch let err as NSError
        {
            app.transcript().write(.Error, text: "StdHighlightTodo couldn't compile '\(pattern)' as a regex: \(err.localizedFailureReason)")
        }
        catch
        {
            app.transcript().write(.Error, text: "StdHighlightTodo unknown error compiling '\(pattern)' as a regex")
        }
    
        // This doesn't provide much customization for users but the standard route of extracting
        // styles from an rtf setting file will be awkward because blowing away the existing comment
        // styling isn't composable. TODO: could use a setting with attribute name/value pairs.
        weight = settings.floatValue("TodoWeight", missing: 5.0)
    }
    
    func render(view: MimsyTextView, range: NSRange)
    {
        if let storage = view.view.textStorage
        {
            re.enumerateMatchesInString(view.text, options: .WithoutAnchoringBounds, range: range) { (result:NSTextCheckingResult?, flags:NSMatchingFlags, stop:UnsafeMutablePointer<ObjCBool>) in
                if let r = result
                {
                    storage.addAttribute(NSStrokeWidthAttributeName, value: NSNumber(float: -self.weight), range: r.range)
                }
            }
        }
    }
    
    var re = try! NSRegularExpression(pattern: "TODO", options: NSRegularExpressionOptions(rawValue: 0))
    var weight: Float = 5.0
}
