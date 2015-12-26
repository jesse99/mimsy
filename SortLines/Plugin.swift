import Cocoa
import MimsyPlugins

class StdSortLines: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItem(title: "Sort Lines", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: sortLines)
            
            app.registerWithSelectionTextContextMenu(.Transform, callback: contextMenu)
        }
        
        return nil
    }
    
    func contextMenu(view: MimsyTextView) -> [TextContextMenuItem]
    {
        if view.selection.containsString("\n")
        {
            return [TextContextMenuItem(title: "Sort Lines", invoke: {_ in self.sortLines()})]
        }
        else
        {
            return []
        }
    }
    
    func title(view: MimsyTextView) -> String?
    {
        return view.selection.containsString("\n") ? "Sort Lines" : nil
    }
    
    func enabled(item: NSMenuItem) -> Bool
    {
        var enabled = false
        
        if let view = app.textView()
        {
            enabled = view.selection.containsString("\n")
        }
        
        return enabled
    }
    
    func sortLines()
    {
        if let view = app.textView()
        {
            // Need to do the trim so that we don't wind up with a blank line.
            let range = view.selectedLineRange()
            let text = view.string.substringWithRange(range)
            let oldText = text.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
            let lines = oldText.componentsSeparatedByString("\n")
            let newText = lines.sort().joinWithSeparator("\n") + "\n"
            view.setText(newText, forRange: range, undoText: "Sort Lines")
        }
    }
}
