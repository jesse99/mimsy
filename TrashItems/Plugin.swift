import Cocoa
import MimsyPlugins

class StdTrashItems: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerProjectContextMenu(getTitle, invoke: trashItems)
        }
        
        return nil
    }
    
    func getTitle(_ files: [MimsyPath], dirs: [MimsyPath]) -> String?
    {
        let count = files.count + dirs.count
        if count > 1
        {
            return "Trash Items"
        }
        else if count == 1
        {
            return "Trash Item"
        }
        else
        {
            return nil
        }
    }
    
    func trashItems(_ files: [MimsyPath], dirs: [MimsyPath])
    {
        for path in files
        {
            trash(path)
        }
        
        for path in dirs
        {
            trash(path)
        }
    }
    
    func trash(_ path: MimsyPath)
    {
        do
        {
            let fm = FileManager.default
            try fm.trashItem(at: path.asURL(), resultingItemURL: nil)
        }
        catch let err as NSError
        {
            app.transcript().write(.error, text: "error moving \(path) to the trash: \(err.localizedFailureReason)")
        }
        catch
        {
            app.transcript().write(.error, text: "unknown error moving \(path) to the trash")
        }
    }
}
