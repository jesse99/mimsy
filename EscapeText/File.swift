import Foundation
import Cocoa
import MimsyPlugins

class StdEscapeText: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItem(title: "Escape HTML", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: html)
            app.addMenuItem(title: "Escape XML", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: xml)
            
            app.registerWithSelectionTextContextMenu(.Transform, title: {_ in
                "Escape HTML"}, invoke: { _ in self.html()})
            app.registerWithSelectionTextContextMenu(.Transform, title: {_ in
                "Escape XML"}, invoke: { _ in self.xml()})
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
    
    func html()
    {
        if let view = app.frontTextView()
        {
            var text = view.selection
            text = text.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
            text = text.stringByReplacingOccurrencesOfString("<", withString: "&lt;")
            text = text.stringByReplacingOccurrencesOfString(">", withString: "&gt;")
            text = text.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
            view.setSelection(text, undoText: "Escape HTML")
        }
    }
    
    func xml()
    {
        if let view = app.frontTextView()
        {
            var text = view.selection
            text = text.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
            text = text.stringByReplacingOccurrencesOfString("<", withString: "&lt;")
            text = text.stringByReplacingOccurrencesOfString(">", withString: "&gt;")
            text = text.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
            text = text.stringByReplacingOccurrencesOfString("'", withString: "&apos;")
            view.setSelection(text, undoText: "Escape XML")
        }
    }
}
