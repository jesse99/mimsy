import Cocoa
import MimsyPlugins

class StdHighlightLine: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerTextView(.SelectionChanged, selectionChanged)
        }
        
        return nil
    }
    
    override func onLoadSettings(settings: MimsySettings)
    {
        let color = settings.stringValue("Color", missing: "PeachPuff")
        app.log("Plugins", "loaded color %@", color)
    }
    
    // The classy way to do this is to store the state of the current line highlighting for a text
    // viewand remove the associated background color when the line changes. Unfortunately we don't 
    // always get notified sufficiently often (I think Cocoa sometimes coalesces text edited
    // notifications). So we'll just brute force it to ensure the display stays consistent.
    //
    // This might impact other plugins that manipulate the back color but those will always
    // be iffy with this plugin (unless they're very transient).
    func selectionChanged(view: MimsyTextView)
    {
        if let view = app.textView(), let managers = view.view.textStorage?.layoutManagers where managers.count > 0
        {
            let layout = managers[0]
            let range = NSRange(location: 0, length: view.string.length)
            layout.removeTemporaryAttribute(NSBackgroundColorAttributeName, forCharacterRange: range)
           
            // Only highlight if the selection is on a single line (and, in the interests of efficiency,
            // shortcut this process for really long selections).
            if view.selectionRange.length < 1024 && !view.selection.containsString("\n")
            {
                let range = view.selectedLineRange()
                layout.addTemporaryAttribute(NSBackgroundColorAttributeName, value: NSColor.blueColor(), forCharacterRange: range)
            }
        }
    }
}
