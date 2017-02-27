import Cocoa
import MimsyPlugins

class StdFindGremlin: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            _ = app.addMenuItem(title: "Find Gremlin", loc: .after, sel: "findPrevious:", enabled: enabled, invoke: findGremlin)
        }
        
        return nil
    }
    
    func enabled(_ item: NSMenuItem) -> Bool
    {
        var enabled = false
        
        if let view = app.textView()
        {
            enabled = !view.text.isEmpty
        }
        
        return enabled
    }
    
    func findGremlin()
    {
        if let view = app.textView()
        {
            // We need random access to the UTF-16 characters to ensure that our selections
            // are sensible so it's easiest to just use NSString.
            let text = view.string
            let index = view.selectionRange.location + 1
            
            for i in index ..< text.length
            {
                let ch = Int(text.character(at: i))
                if (ch < 32 && ch != 9 && ch != 10) || ch > 126
                {
                    let names = app.getUnicodeNames()
                    if ch < names.count && names[ch] != "-"
                    {
                        app.transcript().writeLine(.info, "found \(names[ch]) (U+%04X)", ch)
                    }
                    else
                    {
                        app.transcript().writeLine(.info, "found invalid code point U+%04X", ch)
                    }
                    view.selectionRange = NSMakeRange(i, 1)
                    return
                }
            }
            
            // We could support wrapping around (if the FindWraps setting is set)
            // but that works best with Find and Find Again commands.
            NSBeep()
        }
    }
}
