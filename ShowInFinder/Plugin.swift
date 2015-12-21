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
    
    func getTitle(files: [MimsyPath], dirs: [MimsyPath]) -> String?
    {
        return !files.isEmpty || !dirs.isEmpty ? "Show in Finder" : nil
    }
    
    func showItems(files: [MimsyPath], dirs: [MimsyPath])
    {
        for path in files
        {
            NSWorkspace.sharedWorkspace().selectFile(path.asString(), inFileViewerRootedAtPath: "")
        }

        for path in dirs
        {
            NSWorkspace.sharedWorkspace().selectFile(path.asString(), inFileViewerRootedAtPath: "")
        }
    }
}
