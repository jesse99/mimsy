// Adds menu items to upper and lower case the current selection.
import Cocoa
import MimsyPlugins

class StdChangeCase: MimsyPlugin {
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            var item = NSMenuItem(title: "Upper Case", action: "", keyEquivalent: "")
            app.addMenuItem(item, loc: MenuItemLoc.Sorted, sel: "transformItems:", enabled: enabled, invoke: upperCase)

            item = NSMenuItem(title: "Lower Case", action: "", keyEquivalent: "")
            app.addMenuItem(item, loc: MenuItemLoc.Sorted, sel: "transformItems:", enabled: enabled, invoke: lowerCase)
        }
        
        return nil
    }
    
    func upperCase()
    {
        if let view = app.frontTextView()
        {
            var text = view.selection
            text = text.uppercaseString;
            view.replaceText(text, undoText: "Upper Case")
        }
    }
    
    func lowerCase()
    {
        if let view = app.frontTextView()
        {
            var text = view.selection
            text = text.lowercaseString;
            view.replaceText(text, undoText: "Lower Case")
        }
    }
    
    func enabled(item: NSMenuItem) -> Bool
    {
        var enabled = false
        
        if let view = app.frontTextView()
        {
            enabled = view.selectionRange.length > 0
        }
        
        return enabled
    }
}
