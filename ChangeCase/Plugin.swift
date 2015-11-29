import Cocoa
import MimsyPlugins

class StdChangeCase: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItemTitled("Upper Case", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: upperCase)
            app.addMenuItemTitled("Lower Case", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: lowerCase)
            
            app.registerWithSelectionTextContextMenu(.Transform, title: {_ in
                "Upper Case"}, invoke: { _ in self.upperCase()})
            app.registerWithSelectionTextContextMenu(.Transform, title: {_ in
                "Lower Case"}, invoke: { _ in self.lowerCase()})
        }
        
        return nil
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
    
    func upperCase()
    {
        if let view = app.frontTextView()
        {
            var text = view.selection
            text = text.uppercaseString;
            view.setSelection(text, undoText: "Upper Case")
        }
    }
    
    func lowerCase()
    {
        if let view = app.frontTextView()
        {
            var text = view.selection
            text = text.lowercaseString;
            view.setSelection(text, undoText: "Lower Case")
        }
    }
}
