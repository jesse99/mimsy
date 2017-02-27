import Cocoa
import MimsyPlugins

class StdChangeCase: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            _ = app.addMenuItem(title: "Upper Case", loc: .sorted, sel: "transformItems:", enabled: enabled, invoke: upperCase)
            _ = app.addMenuItem(title: "Lower Case", loc: .sorted, sel: "transformItems:", enabled: enabled, invoke: lowerCase)
            
            app.registerWithSelectionTextContextMenu(.transform, callback: contextMenu)
        }
        
        return nil
    }
    
    func contextMenu(_ view: MimsyTextView) -> [TextContextMenuItem]
    {
        return [TextContextMenuItem(title: "Upper Case", invoke: {_ in self.upperCase()}),
            TextContextMenuItem(title: "Lower Case", invoke: {_ in self.lowerCase()})]
    }
    
    func enabled(_ item: NSMenuItem) -> Bool
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
            text = text.uppercased()
            view.setSelection(text, undoText: "Upper Case")
        }
    }
    
    func lowerCase()
    {
        if let view = app.textView()
        {
            var text = view.selection
            text = text.lowercased()
            view.setSelection(text, undoText: "Lower Case")
        }
    }
}
