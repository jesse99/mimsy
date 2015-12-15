import Cocoa
import MimsyPlugins

class StdCopyPaths: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerNoSelectionTextContextMenu(.Start, title: getFileTitle, invoke: copyFileItem)
            app.registerProjectContextMenu(getProjectTitle, invoke: copyProjectItems)
        }
        
        return nil
    }
    
    func getFileTitle(view: MimsyTextView) -> String?
    {
        return view.path != nil ? "Copy Path" : nil
    }
    
    func getProjectTitle(files: [String], dirs: [String]) -> String?
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
        pb.writeObjects([view.path!])
    }
    
    func copyProjectItems(files: [String], dirs: [String])
    {
        let pb = NSPasteboard.generalPasteboard()
        pb.clearContents()
        pb.writeObjects(files)
        pb.writeObjects(dirs)
    }
}
