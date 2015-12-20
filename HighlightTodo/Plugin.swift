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

            let text = settings.stringValue("TodoStyle", missing: "stroke=very-bold")
            styles = try MimsyStyle.parse(app, text)
        }
        catch let err as NSError
        {
            app.transcript().write(.Error, text: "StdHighlightTodo couldn't compile '\(pattern)' as a regex: \(err.localizedFailureReason)\n")
        }
        catch let err as MimsyError
        {
            app.transcript().write(.Error, text: "StdHighlightTodo had an error loading settings: \(err.text)\n")
        }
        catch
        {
            app.transcript().write(.Error, text: "StdHighlightTodo unknown error compiling '\(pattern)' as a regex\n")
        }
    }
    
    func render(view: MimsyTextView, range: NSRange)
    {
        if let storage = view.view.textStorage
        {
            re.enumerateMatchesInString(view.text, options: .WithoutAnchoringBounds, range: range) { (result:NSTextCheckingResult?, flags:NSMatchingFlags, stop:UnsafeMutablePointer<ObjCBool>) in
                if let r = result
                {
                    MimsyStyle.apply(storage, self.styles, r.range)
                }
            }
        }
    }
    
    var re = try! NSRegularExpression(pattern: "TODO", options: NSRegularExpressionOptions(rawValue: 0))
    var styles: [MimsyStyle] = []
}
