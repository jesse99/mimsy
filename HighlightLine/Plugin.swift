import Cocoa
import MimsyPlugins

class StdHighlightLine: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerTextView(.selectionChanged, selectionChanged)
        }
        
        return nil
    }
    
    override func onLoadSettings(_ settings: MimsySettings)
    {
        let name = settings.stringValue("LineColor", missing: "PeachPuff")
        if let candidate = app.mimsyColor(name)
        {
            color = candidate
        }
        else
        {
            app.log("Plugins", "bad highlight-line color name: '%@", name)
        }
        
        maxSelLen = settings.intValue("MaxSelLen", missing: 1024)
    }
    
    // The classy way to do this is to store the state of the current line highlighting for a text
    // viewand remove the associated background color when the line changes. Unfortunately we don't 
    // always get notified sufficiently often (I think Cocoa sometimes coalesces text edited
    // notifications). So we'll just brute force it to ensure the display stays consistent.
    //
    // This might impact other plugins that manipulate the back color but those will always
    // be iffy with this plugin (unless they're very transient).
    func selectionChanged(_ view: MimsyTextView)
    {
        if let view = app.textView(), let managers = view.view.textStorage?.layoutManagers, managers.count > 0
        {
            let layout = managers[0]
            let range = NSRange(location: 0, length: view.string.length)
            layout.removeTemporaryAttribute(NSBackgroundColorAttributeName, forCharacterRange: range)
           
            // Only highlight if the selection is on a single line (and, in the interests of efficiency,
            // shortcut this process for really long selections).
            if view.selectionRange.length < maxSelLen && !view.selection.contains("\n")
            {
                let range = view.selectedLineRange()
                layout.addTemporaryAttribute(NSBackgroundColorAttributeName, value: color, forCharacterRange: range)
            }
        }
    }
    
    var color: NSColor = NSColor.blue
    var maxSelLen = 1024
}
