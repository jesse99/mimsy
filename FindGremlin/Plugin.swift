import Cocoa
import MimsyPlugins

class StdFindGremlin: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItemTitled("Find Gremlin", loc: .After, sel: "findPrevious:", enabled: enabled, invoke: findGremlin)
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
    
    // TODO:
    // write a better message to the transcript
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
                let ch = text.characterAtIndex(i)
                if (ch < 32 && ch != 9 && ch != 10 && ch != 13) || ch > 126
                {
                    app.transcript().writeLine(.Info, "found \(ch)")
                    view.selectionRange = NSMakeRange(i, 1)
                    return
                }
            }
            
            NSBeep()
        }
    }
}
