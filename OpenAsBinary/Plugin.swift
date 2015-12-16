import Cocoa
import MimsyPlugins

class StdOpenAsBinary: MimsyPlugin
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
            return "Open as Binary"
        }
        else
        {
            return nil
        }
    }
    
    func duplicateItems(files: [String], dirs: [String])
    {
        for path in files
        {
            app.openAsBinary(path)
        }
    }
}
