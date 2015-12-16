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
    
    func getTitle(files: [String], dirs: [String]) -> String?
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
    
    func trashItems(files: [String], dirs: [String])
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
    
    func trash(path: String)
    {
        do
        {
            let fm = NSFileManager.defaultManager()
            let url = NSURL(fileURLWithPath: path)
            try fm.trashItemAtURL(url, resultingItemURL: nil)
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
