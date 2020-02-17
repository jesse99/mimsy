import Cocoa
import MimsyPlugins

class StdDuplicateFile: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerProjectContextMenu(getTitle, invoke: duplicateItems)
        }
        
        return nil
    }
    
    func getTitle(_ files: [MimsyPath], dirs: [MimsyPath]) -> String?
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
    
    func duplicateItems(_ files: [MimsyPath], dirs: [MimsyPath])
    {
        let fm = FileManager.default
        for oldPath in files
        {
            do
            {
                let newPath = oldPath.makeUnique()
                try fm.copyItem(atPath: oldPath.asString(), toPath: newPath.asString())
            }
            catch let err as NSError
            {
                app.transcript().write(.error, text: "error copying \(oldPath): \(String(describing: err.localizedFailureReason))")
            }
            catch
            {
                app.transcript().write(.error, text: "unknown error copying \(oldPath)")
            }
        }
    }
}
