import Cocoa
import MimsyPlugins

class StdHighlightTodo: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerApplyStyle("Comment", render)
        }
        
        return nil
    }
    
    override func onLoadSettings(_ settings: MimsySettings)
    {
        var words = settings.stringValues("TodoWord")
        words = words.map {"(" + $0 + ")"}
        let pattern = words.joined(separator: "|")
        
        do
        {
            re = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options(rawValue: 0))

            let text = settings.stringValue("TodoStyle", missing: "stroke=very-bold")
            styles = try MimsyStyle.parse(app, text)
        }
        catch let err as NSError
        {
            app.transcript().write(.error, text: "StdHighlightTodo couldn't compile '\(pattern)' as a regex: \(err.localizedFailureReason)\n")
        }
        catch let err as MimsyError
        {
            app.transcript().write(.error, text: "StdHighlightTodo had an error loading settings: \(err.text)\n")
        }
        catch
        {
            app.transcript().write(.error, text: "StdHighlightTodo unknown error compiling '\(pattern)' as a regex\n")
        }
    }
    
    func render(_ view: MimsyTextView, range: NSRange)
    {
        if let storage = view.view.textStorage
        {
            re.enumerateMatches(in: view.text, options: .withoutAnchoringBounds, range: range) { (result:NSTextCheckingResult?, flags:NSRegularExpression.MatchingFlags, stop:UnsafeMutablePointer<ObjCBool>) in
                if let r = result
                {
                    MimsyStyle.apply(storage, self.styles, r.range)
                }
            }
        }
    }
    
    var re = try! NSRegularExpression(pattern: "TODO", options: NSRegularExpression.Options(rawValue: 0))
    var styles: [MimsyStyle] = []
}
