import Cocoa
import MimsyPlugins

class StdShowTrailingWhitespace: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItem(title: "Show Trailing Whitespace", loc: .Sorted, sel: "showItems:", enabled: enabled, invoke: toggleShow)
        }
        
        return nil
    }
    
    func enabled(item: NSMenuItem) -> Bool
    {
        var enabled = false
        var title = "Show Trailing Whitespace"
        
        if let view = app.textView() where view.language != nil
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
    
    func toggleShow()
    {
        userEnabled = !userEnabled
        
        if let view = app.textView() where view.language != nil
        {
            setMapping(view)
        }
    }

    override func onLoadSettings(settings: MimsySettings)
    {
        enabled = settings.boolValue("ShowTrailingWhitespace", missing: false)
        style = settings.stringValue("TrailingWhiteSpaceStyle", missing: "Error")
        chars = settings.stringValue("TrailingWhitespaceChars", missing: "•")
    }
    
    override func onMainChanged(controller: NSWindowController?)
    {
        if let view = controller as? MimsyTextView where view.language != nil
        {
            setMapping(view)
        }
    }
    
    func setMapping(view: MimsyTextView)
    {
        if enabled || userEnabled
        {
            view.addMapping(re, style: style, chars: chars, options: .UseGlyphsForEachChar)
        }
        else
        {
            view.removeMapping(re)
        }
    }
    
    let re = try! NSRegularExpression(pattern: "\\S+([\\ \\t]+)\\n", options: NSRegularExpressionOptions(rawValue: 0))
    var userEnabled = false
    var enabled = false
    var style = ""
    var chars = ""
}
