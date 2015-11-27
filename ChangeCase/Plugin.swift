// Adds menu items to upper and lower case the current selection.
import Cocoa
import MimsyPlugins

class ChangeCase: MimsyPlugin {
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            let item = NSMenuItem(title: "Upper Case", action: "", keyEquivalent: "")
            app.addMenuItem(item, loc: MenuItemLoc.Sorted, sel: "transformItems:", enabled: nil, invoke: upperCase)
        }
        
        return nil
    }
    
    func upperCase()
    {
        log("Plugin", format: "your upper case here!")
    }
}
