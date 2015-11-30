import Cocoa
import MimsyPlugins

class StdSortLines: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItem(title: "Sort Lines", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: sortLines)
            
            app.registerWithSelectionTextContextMenu(.Transform, title: {_ in
                "Sort Lines"}, invoke: { _ in self.sortLines()})
        }
        
        return nil
    }
    
    func enabled(item: NSMenuItem) -> Bool
    {
        var enabled = false
        
        if let view = app.frontTextView()
        {
            enabled = view.selectionRange.length > 0 && view.selection.containsString("\n")
        }
        
        return enabled
    }
    
    func sortLines()
    {
        if let view = app.frontTextView()
        {
            // Need to do the trim so that we don't wind up with a blank line.
            let (text, range) = view.selectionLines()
            let oldText = text.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
            let lines = oldText.componentsSeparatedByString("\n")
            let newText = lines.sort().joinWithSeparator("\n") + "\n"
            view.setText(newText, forRange: range, undoText: "Sort Lines")
        }
    }
}
