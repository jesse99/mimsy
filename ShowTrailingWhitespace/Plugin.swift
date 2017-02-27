import Cocoa
import MimsyPlugins

class StdShowTrailingWhitespace: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            _ = app.addMenuItem(title: "Show Trailing Whitespace", loc: .sorted, sel: "showItems:", enabled: enabled, invoke: toggleEnabled)
        }
        
        return nil
    }
    
    func enabled(_ item: NSMenuItem) -> Bool
    {
        var enabled = false
        var title = "Show Trailing Whitespace"
        
        if let view = app.textView(), view.language != nil
        {
            enabled = true
            if self.enabled || userEnabled
            {
                title = "Hide Trailing Whitespace"
            }
        }
        
        item.title = title
        return enabled
    }
    
    func toggleEnabled()
    {
        userEnabled = !userEnabled
        
        if let view = app.textView(), view.language != nil
        {
            setMapping(view)
        }
    }

    override func onLoadSettings(_ settings: MimsySettings)
    {
        enabled = settings.boolValue("ShowTrailingWhitespace", missing: false)
        style = settings.stringValue("TrailingWhiteSpaceStyle", missing: "Error")
        chars = settings.stringValue("TrailingWhitespaceChars", missing: "•")
    }
    
    override func onMainChanged(_ controller: NSWindowController?)
    {
        if let view = controller as? MimsyTextView, view.language != nil
        {
            setMapping(view)
        }
    }
    
    func setMapping(_ view: MimsyTextView)
    {
        if enabled || userEnabled
        {
            view.addMapping(re, style: style, chars: chars, options: .useGlyphsForEachChar)
        }
        else
        {
            view.removeMapping(re)
        }
    }
    
    let re = try! NSRegularExpression(pattern: "\\S+([\\ \\t]+)\\n", options: NSRegularExpression.Options(rawValue: 0))
    var userEnabled = false
    var enabled = false
    var style = ""
    var chars = ""
}
