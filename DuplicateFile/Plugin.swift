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
    
    func getTitle(files: [String], dirs: [String]) -> String?
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
    
    func duplicateItems(files: [String], dirs: [String])
    {
        let fm = NSFileManager.defaultManager()
        for oldPath in files
        {
            do
            {
                let newPath = oldPath.stringByFindingUniquePath()
                try fm.copyItemAtPath(oldPath, toPath: newPath)
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
