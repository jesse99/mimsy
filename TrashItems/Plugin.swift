import Cocoa
import MimsyPlugins

class StdTrashItems: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerProjectContextMenu(getTitle, invoke: trashItems)
        }
        
        return nil
    }
    
    func getTitle(files: [MimsyPath], dirs: [MimsyPath]) -> String?
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
    
    func trashItems(files: [MimsyPath], dirs: [MimsyPath])
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
    
    func trash(path: MimsyPath)
    {
        do
        {
            let fm = NSFileManager.defaultManager()
            try fm.trashItemAtURL(path.asURL(), resultingItemURL: nil)
        }
        catch let err as NSError
        {
            app.transcript().write(.Error, text: "error moving \(path) to the trash: \(err.localizedFailureReason)")
        }
        catch
        {
            app.transcript().write(.Error, text: "unknown error moving \(path) to the trash")
        }
    }
}
