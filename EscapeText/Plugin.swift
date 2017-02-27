import Foundation
import Cocoa
import MimsyPlugins

class StdEscapeText: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            _ = app.addMenuItem(title: "Escape HTML", loc: .sorted, sel: "transformItems:", enabled: enabled, invoke: html)
            _ = app.addMenuItem(title: "Escape XML", loc: .sorted, sel: "transformItems:", enabled: enabled, invoke: xml)
            
            app.registerWithSelectionTextContextMenu(.transform, callback: contextMenu)
        }
        
        return nil
    }
    
    func contextMenu(_ view: MimsyTextView) -> [TextContextMenuItem]
    {
        return [TextContextMenuItem(title: "Escape HTML", invoke: {_ in self.html()}),
            TextContextMenuItem(title: "Escape XML", invoke: {_ in self.xml()})]
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
    
    func html()
    {
        if let view = app.textView()
        {
            var text = view.selection
            text = text.replacingOccurrences(of: "&", with: "&amp;")
            text = text.replacingOccurrences(of: "<", with: "&lt;")
            text = text.replacingOccurrences(of: ">", with: "&gt;")
            text = text.replacingOccurrences(of: "\"", with: "&quot;")
            view.setSelection(text, undoText: "Escape HTML")
        }
    }
    
    func xml()
    {
        if let view = app.textView()
        {
            var text = view.selection
            text = text.replacingOccurrences(of: "&", with: "&amp;")
            text = text.replacingOccurrences(of: "<", with: "&lt;")
            text = text.replacingOccurrences(of: ">", with: "&gt;")
            text = text.replacingOccurrences(of: "\"", with: "&quot;")
            text = text.replacingOccurrences(of: "'", with: "&apos;")
            view.setSelection(text, undoText: "Escape XML")
        }
    }
}
