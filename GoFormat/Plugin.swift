import Cocoa
import MimsyPlugins

class StdGoFormat: MimsyPlugin {
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            self.log("Plugins", "loaded go format!")
        }
        
        return nil
    }
}
