import Cocoa
import MimsyPlugins

class StdShowInFinder: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerProjectContextMenu(getTitle, invoke: showItems)
        }
        
        return nil
    }
    
    func getTitle(files: [String], dirs: [String]) -> String?
    {
        return !files.isEmpty || !dirs.isEmpty ? "Show in Finder" : nil
    }
    
    func showItems(files: [String], dirs: [String])
    {
        for path in files
        {
            NSWorkspace.sharedWorkspace().selectFile(path, inFileViewerRootedAtPath: "")
        }

        for path in dirs
        {
            NSWorkspace.sharedWorkspace().selectFile(path, inFileViewerRootedAtPath: "")
        }
    }
}
