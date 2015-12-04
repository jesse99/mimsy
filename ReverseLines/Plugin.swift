import Cocoa
import MimsyPlugins

class StdReverseLines: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItem(title: "Reverse Lines", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: reverseLines)
            
            app.registerWithSelectionTextContextMenu(.Transform, title: title, invoke: { _ in self.reverseLines()})
        }
        
        return nil
    }
    
    func title(view: MimsyTextView) -> String?
    {
        return view.selection.containsString("\n") ? "Reverse Lines" : nil
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
    
    func reverseLines()
    {
        if let view = app.textView()
        {
            // Need to do the trim so that we don't wind up with a blank line.
            let range = view.selectedLineRange()
            let text = view.string.substringWithRange(range)
            let oldText = text.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
            let lines = oldText.componentsSeparatedByString("\n")
            let newText = lines.reverse().joinWithSeparator("\n") + "\n"
            view.setText(newText, forRange: range, undoText: "Reverse Lines")
        }
    }
}
