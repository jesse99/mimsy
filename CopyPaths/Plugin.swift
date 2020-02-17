import Cocoa
import MimsyPlugins

class StdCopyPaths: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerNoSelectionTextContextMenu(.start, callback: contextMenu)
            app.registerProjectContextMenu(getProjectTitle, invoke: copyProjectItems)
        }
        
        return nil
    }
    
    func contextMenu(_ view: MimsyTextView) -> [TextContextMenuItem]
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
    
    func getProjectTitle(_ files: [MimsyPath], dirs: [MimsyPath]) -> String?
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
    
    func copyFileItem(_ view: MimsyTextView)
    {
        let pb = NSPasteboard.general
        let text = view.path!.asString() as NSString
        pb.clearContents()
        pb.writeObjects([text])
    }
    
    func copyProjectItems(_ files: [MimsyPath], dirs: [MimsyPath])
    {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(files.map {$0.asString() as NSString})
        pb.writeObjects(dirs.map {$0.asString() as NSString})
    }
}
