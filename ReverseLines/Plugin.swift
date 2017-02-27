import Cocoa
import MimsyPlugins

class StdReverseLines: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            _ = app.addMenuItem(title: "Reverse Lines", loc: .sorted, sel: "transformItems:", enabled: enabled, invoke: reverseLines)
            
            app.registerWithSelectionTextContextMenu(.transform, callback: contextMenu)
        }
        
        return nil
    }
    
    func contextMenu(_ view: MimsyTextView) -> [TextContextMenuItem]
    {
        if view.selection.contains("\n")
        {
            return [TextContextMenuItem(title: "Reverse Lines", invoke: {_ in self.reverseLines()})]
        }
        else
        {
            return []
        }
    }
    
    func enabled(_ item: NSMenuItem) -> Bool
    {
        var enabled = false
        
        if let view = app.textView()
        {
            enabled = view.selection.contains("\n")
        }
        
        return enabled
    }
    
    func reverseLines()
    {
        if let view = app.textView()
        {
            // Need to do the trim so that we don't wind up with a blank line.
            let range = view.selectedLineRange()
            let text = view.string.substring(with: range)
            let oldText = text.trimmingCharacters(in: CharacterSet.newlines)
            let lines = oldText.components(separatedBy: "\n")
            let newText = lines.reversed().joined(separator: "\n") + "\n"
            view.setText(newText, forRange: range, undoText: "Reverse Lines")
        }
    }
}
