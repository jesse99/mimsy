import Cocoa
import MimsyPlugins

class StdCopyPaths: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerNoSelectionTextContextMenu(.Start, callback: contextMenu)
            app.registerProjectContextMenu(getProjectTitle, invoke: copyProjectItems)
        }
        
        return nil
    }
    
    func contextMenu(view: MimsyTextView) -> [TextContextMenuItem]
    {
        if view.path != nil
        {
            return [TextContextMenuItem(title: "Copy Path", invoke: copyFileItem)]
        }
        else
        {
            return []
        }
    }
    
    func getProjectTitle(files: [MimsyPath], dirs: [MimsyPath]) -> String?
    {
        let count = files.count + dirs.count
        
        if count == 1
        {
            return "Copy Path"
        }
        else if count > 1
        {
            return "Copy Paths"
        }
        else
        {
            return nil
        }
    }
    
    func copyFileItem(view: MimsyTextView)
    {
        let pb = NSPasteboard.generalPasteboard()
        pb.clearContents()
        pb.writeObjects([view.path!.asString()])
    }
    
    func copyProjectItems(files: [MimsyPath], dirs: [MimsyPath])
    {
        let pb = NSPasteboard.generalPasteboard()
        pb.clearContents()
        pb.writeObjects(files.map {$0.asString()})
        pb.writeObjects(dirs.map {$0.asString()})
    }
}
