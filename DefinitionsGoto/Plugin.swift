import Foundation
import Cocoa
import MimsyPlugins

class StdDefinitionsGoto: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerWithSelectionTextContextMenu(.lookup, callback: contextMenu)
        }

        return nil
    }
    
    func contextMenu(_ view: MimsyTextView) -> [TextContextMenuItem]
    {
        var menuItems: [TextContextMenuItem] = []
        
        if let project = view.project, let plugin = definitionsPlugin, view.selectionRange.length < 200
        {
            let name = view.selection
            
            var items = plugin.declarations(project, name: name)
            addMenuItems("Goto Declaration", &menuItems, name, items)

            items = plugin.definitions(project, name: name)
            addMenuItems("Goto Definition", &menuItems, name, items)
        }
        
        return menuItems
    }
    
    func addMenuItems(_ baseTitle: String, _ menuItems: inout [TextContextMenuItem], _ name: String, _ items: [ItemPath])
    {
        var items = items
        items.sort
        {
            let f1 = $0.path.lastComponent()
            let f2 = $1.path.lastComponent()
            return f1 < f2 || (f1 == f2 && $0.location < $1.location)
        }
        
        let len = name.lengthOfBytes(using: String.Encoding.utf16)/2
        for item in items
        {
            let title = getTitle(baseTitle, items, item)
            menuItems.append(TextContextMenuItem(title: title, invoke: {_ in
                self.gotoItem(item.path, location: item.location, length: len)
            }))
        }
    }
    
    func getTitle(_ base: String, _ items: [ItemPath], _ item: ItemPath) -> String
    {
        if items.count == 1
        {
            return base
        }
        else
        {
            let matchsInPath = items.countFiltered {$0.path == item.path}
            if matchsInPath == 1
            {
                return "\(base) in \(item.path.lastComponent())"
            }
            else
            {
                // TODO: Would be slicker to use a line number instead of a location.
                // Although that would require a second pass through each file as well
                // as a lookup to match a location (or range) to a line number (or lines).
                return "\(base) in \(item.path.lastComponent()) at \(item.location)"
            }
        }
    }
    
    func gotoItem(_ path: MimsyPath, location: Int, length: Int)
    {
        app.open(path, withRange: NSRange(location: location, length: length))
    }
}
