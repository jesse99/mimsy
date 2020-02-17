import Cocoa
import MimsyPlugins

class StdNewDirectory: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerProjectContextMenu(getTitle, invoke: createItem)
        }
        
        return nil
    }
    
    func getTitle(_ files: [MimsyPath], dirs: [MimsyPath]) -> String?
    {
        // We'll keep things simple and only create a new directory next
        // to a single item. This way we avoid creating a bunch of sibling
        // directories which the user probably doesn't want to do and avoid
        // the complexities of tracking what was created where to work around
        // that.
        return files.count + dirs.count == 1 ? "New Directory" : nil
    }
    
    func createItem(_ files: [MimsyPath], dirs: [MimsyPath])
    {
        for oldPath in files
        {
            let path = oldPath.popComponent().append(component: "untitled")
            create(path)
        }

        for oldPath in dirs
        {
            // We could either create a sibling directory or a child directory.
            // Not entirely clear which is best so we'll do what New File does
            // and create a child directory.
            let path = oldPath.append(component: "untitled")
            create(path)
        }
    }
    
    func create(_ newPath: MimsyPath)
    {
        var newPath = newPath
        newPath = newPath.makeUnique()

        do
        {
            let fm = FileManager.default
            try fm.createDirectory(atPath: newPath.asString(), withIntermediateDirectories: true, attributes: nil)
        }
        catch let err as NSError
        {
            app.transcript().write(.error, text: "error creating \(newPath): \(String(describing: err.localizedFailureReason))")
        }
        catch
        {
            app.transcript().write(.error, text: "unknown error creating \(newPath)")
        }
    }
}
