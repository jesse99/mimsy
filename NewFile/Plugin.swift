import Cocoa
import MimsyPlugins

class StdNewFile: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerProjectContextMenu(getTitle, invoke: createItem)
        }
        
        return nil
    }
    
    func getTitle(files: [MimsyPath], dirs: [MimsyPath]) -> String?
    {
        // We'll keep things simple and only create a new file next to a 
        // single item. This way we avoid creating a bunch of sibling files 
        // which the user probably doesn't want to do and avoid the 
        // complexities of tracking what was created where to work around that.
        return files.count + dirs.count == 1 ? "New File" : nil
    }
    
    func createItem(files: [MimsyPath], dirs: [MimsyPath])
    {
        for oldPath in files
        {
            let path = oldPath.popComponent().append(component: "untitled")
            create(path)
        }
        
        for oldPath in dirs
        {
            let path = oldPath.append(component: "untitled")
            create(path)
        }
    }
    
    func create(var newPath: MimsyPath)
    {
        newPath = newPath.makeUnique()
        
        // We could do something like use a setting to initialize the new file's
        // contents but it seems better to use a snippet instead.
        let fm = NSFileManager.defaultManager()
        if !fm.createFileAtPath(newPath.asString(), contents: nil, attributes: nil)
        {
            app.transcript().write(.Error, text: "unknown error creating \(newPath)")
        }
    }
}
