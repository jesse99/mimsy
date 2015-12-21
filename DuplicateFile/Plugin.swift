import Cocoa
import MimsyPlugins

class StdDuplicateFile: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerProjectContextMenu(getTitle, invoke: duplicateItems)
        }
        
        return nil
    }
    
    func getTitle(files: [MimsyPath], dirs: [MimsyPath]) -> String?
    {
        if dirs.isEmpty && !files.isEmpty
        {
            return files.count > 1 ? "Duplicate Files" : "Duplicate File"
        }
        else
        {
            return nil
        }
    }
    
    func duplicateItems(files: [MimsyPath], dirs: [MimsyPath])
    {
        let fm = NSFileManager.defaultManager()
        for oldPath in files
        {
            do
            {
                let newPath = oldPath.makeUnique()
                try fm.copyItemAtPath(oldPath.asString(), toPath: newPath.asString())
            }
            catch let err as NSError
            {
                app.transcript().write(.Error, text: "error copying \(oldPath): \(err.localizedFailureReason)")
            }
            catch
            {
                app.transcript().write(.Error, text: "unknown error copying \(oldPath)")
            }
        }
    }
}
