import Cocoa
import MimsyPlugins

class StdShowInFinder: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            app.registerProjectContextMenu(getTitle, invoke: showItems)
        }
        
        return nil
    }
    
    func getTitle(_ files: [MimsyPath], dirs: [MimsyPath]) -> String?
    {
        return !files.isEmpty || !dirs.isEmpty ? "Show in Finder" : nil
    }
    
    func showItems(_ files: [MimsyPath], dirs: [MimsyPath])
    {
        for path in files
        {
            NSWorkspace.shared().selectFile(path.asString(), inFileViewerRootedAtPath: "")
        }

        for path in dirs
        {
            NSWorkspace.shared().selectFile(path.asString(), inFileViewerRootedAtPath: "")
        }
    }
}
