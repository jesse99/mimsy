import Cocoa
import MimsyPlugins

class StdChangeCase: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItem(title: "Upper Case", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: upperCase)
            app.addMenuItem(title: "Lower Case", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: lowerCase)
            
            app.registerWithSelectionTextContextMenu(.Transform, callback: contextMenu)
        }
        
        return nil
    }
    
    func contextMenu(view: MimsyTextView) -> [TextContextMenuItem]
    {
        return [TextContextMenuItem(title: "Upper Case", invoke: {_ in self.upperCase()}),
            TextContextMenuItem(title: "Lower Case", invoke: {_ in self.lowerCase()})]
    }
    
    func enabled(item: NSMenuItem) -> Bool
    {
        var enabled = false
        
        if let view = app.textView()
        {
            enabled = view.selectionRange.length > 0
        }
        
        return enabled
    }
    
    func upperCase()
    {
        if let view = app.textView()
        {
            var text = view.selection
            text = text.uppercaseString
            view.setSelection(text, undoText: "Upper Case")
        }
    }
    
    func lowerCase()
    {
        if let view = app.textView()
        {
            var text = view.selection
            text = text.lowercaseString
            view.setSelection(text, undoText: "Lower Case")
        }
    }
}
