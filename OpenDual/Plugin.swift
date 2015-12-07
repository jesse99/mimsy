import Cocoa
import MimsyPlugins

class StdOpenDual: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        return nil
    }
    
    override func onLoadSettings(settings: MimsySettings)
    {
        app.clearRegisterTextViewKey(bundle.bundleIdentifier!)        
        for key in settings.stringValues("DualKey")
        {
            app.registerTextViewKey(key, bundle.bundleIdentifier!, openDual)
        }

        mappings = []
        for dual in settings.stringValues("FileDual")
        {
            mappings.append(Mapping(app, dual))
        }
    }
    
    func openDual(view: MimsyTextView) -> Bool
    {
        if let path = view.path
        {
            let stem = path.stringByDeletingPathExtension

            let names = findNames(path as String)
            for name in names
            {
                if name.hasPrefix(".")
                {
                    app.open(stem + name)
                }
                else
                {
                    app.open(name)
                }
            }
        }

        return true
    }
    
    func findNames(path: String) -> [String]
    {
        for mapping in mappings
        {
            if mapping.glob.matches(path)
            {
                return mapping.names
            }
        }
        
        return []
    }
    
    struct Mapping
    {
        let glob: MimsyGlob
        let names: [String]
        
        init(_ app: MimsyApp, _ text: String)
        {
            var parts = text.componentsSeparatedByString(" ")
            glob = app.globWithString(parts.removeFirst())
            names = parts
        }
    }
    
    var mappings: [Mapping] = []
}
