import Cocoa
import MimsyPlugins

class StdFindGremlin: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItem(title: "Find Gremlin", loc: .After, sel: "findPrevious:", enabled: enabled, invoke: findGremlin)
        }
        
        return nil
    }
    
    func enabled(item: NSMenuItem) -> Bool
    {
        var enabled = false
        
        if let view = app.frontTextView()
        {
            enabled = !view.text.isEmpty
        }
        
        return enabled
    }
    
    func findGremlin()
    {
        if let view = app.frontTextView()
        {
            // We need random access to the UTF-16 characters to ensure that our selections
            // are sensible so it's easiest to just use NSString.
            let text = view.text as NSString
            let index = view.selectionRange.location + 1
            
            for var i = index; i < text.length; ++i
            {
                let ch = Int(text.characterAtIndex(i))
                if (ch < 32 && ch != 9 && ch != 10 && ch != 13) || ch > 126
                {
                    let names = app.getUnicodeNames()
                    if ch < names.count && names[ch] != "-"
                    {
                        app.transcript().writeLine(.Info, "found \(names[ch]) (U+%04X)", ch)
                    }
                    else
                    {
                        app.transcript().writeLine(.Info, "found invalid code point U+%04X", ch)
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
