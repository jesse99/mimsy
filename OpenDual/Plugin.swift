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
        app.removeKeyHelp(bundle.bundleIdentifier!, "text editor")
        
        for key in settings.stringValues("DualKey")
        {
            app.registerTextViewKey(key, bundle.bundleIdentifier!, openDual)
            app.addKeyHelp(bundle.bundleIdentifier!, "text editor", key, "Opens a file associated with the current file (e.g. a source file's header).")
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
            let stem = path.popExtension()

            let names = findNames(path)
            for name in names
            {
                switch name
                {
                case .Extension(let name):
                    app.open(stem.append(extensionName: name))
                case .Path(let p):
                    app.open(p)
                }
            }
        }

        return true
    }
    
    func findNames(path: MimsyPath) -> [Name]
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
    
    enum Name
    {
        case Extension(String)
        case Path(MimsyPath)
        
        static func parse(text: String) -> Name
        {
            return text.hasPrefix(".") ?
                .Extension(text.substringFromIndex(text.startIndex.advancedBy(1))) :
                .Path(MimsyPath(withString: text))
        }
    }
    
    struct Mapping
    {
        let glob: MimsyGlob
        let names: [Name]
        
        init(_ app: MimsyApp, _ text: String)
        {
            var parts = text.componentsSeparatedByString(" ")
            glob = app.globWithString(parts.removeFirst())
            names = parts.map {Name.parse($0)}
        }
    }
    
    var mappings: [Mapping] = []
}
