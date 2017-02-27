import Cocoa
import MimsyPlugins

class StdSortLines: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            _ = app.addMenuItem(title: "Sort Lines", loc: .sorted, sel: "transformItems:", enabled: enabled, invoke: sortLines)
            
            app.registerWithSelectionTextContextMenu(.transform, callback: contextMenu)
        }
        
        return nil
    }
    
    func contextMenu(_ view: MimsyTextView) -> [TextContextMenuItem]
    {
        if view.selection.contains("\n")
        {
            return [TextContextMenuItem(title: "Sort Lines", invoke: {_ in self.sortLines()})]
        }
        else
        {
            return []
        }
    }
    
    func title(_ view: MimsyTextView) -> String?
    {
        return view.selection.contains("\n") ? "Sort Lines" : nil
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
    
    func sortLines()
    {
        if let view = app.textView()
        {
            // Need to do the trim so that we don't wind up with a blank line.
            let range = view.selectedLineRange()
            let text = view.string.substring(with: range)
            let oldText = text.trimmingCharacters(in: CharacterSet.newlines)
            let lines = oldText.components(separatedBy: "\n")
            let newText = lines.sorted().joined(separator: "\n") + "\n"
            view.setText(newText, forRange: range, undoText: "Sort Lines")
        }
    }
}
