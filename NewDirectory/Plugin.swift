import Cocoa
import MimsyPlugins

class StdNewDirectory: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerProjectContextMenu(getTitle, invoke: createItem)
        }
        
        return nil
    }
    
    func getTitle(files: [String], dirs: [String]) -> String?
    {
        // We'll keep things simple and only create a new directory next
        // to a single item. This way we avoid creating a bunch of sibling
        // directories which the user probably doesn't want to do and avoid
        // the complexities of tracking what was created where to work around
        // that.
        return files.count + dirs.count == 1 ? "New Directory" : nil
    }
    
    func createItem(files: [String], dirs: [String])
    {
        for oldPath in files
        {
            var path: NSString = (oldPath as NSString).stringByDeletingLastPathComponent
            path = path.stringByAppendingPathComponent("untitled")
            create(path as String)
        }

        for oldPath in dirs
        {
            // We could either create a sibling directory or a child directory.
            // Not entirely clear which is best so we'll do what New File does
            // and create a child directory.
            let path = (oldPath as NSString).stringByAppendingPathComponent("untitled")
            create(path)
        }
    }
    
    func create(var newPath: String)
    {
        newPath = newPath.stringByFindingUniquePath()

        do
        {
            let fm = NSFileManager.defaultManager()
            try fm.createDirectoryAtPath(newPath, withIntermediateDirectories: true, attributes: nil)
        }
        catch let err as NSError
        {
            app.transcript().write(.Error, text: "error creating \(newPath): \(err.localizedFailureReason)")
        }
        catch
        {
            app.transcript().write(.Error, text: "unknown error creating \(newPath)")
        }
    }
}
