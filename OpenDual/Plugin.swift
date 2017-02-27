import Cocoa
import MimsyPlugins

class StdOpenDual: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        return nil
    }
    
    override func onLoadSettings(_ settings: MimsySettings)
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
    
    func openDual(_ view: MimsyTextView) -> Bool
    {
        if let originalPath = view.path
        {
            var fileNames: [String] = []
            
            let names = findNames(originalPath)
            let stem = originalPath.popExtension().lastComponent()
            for name in names
            {
                switch name
                {
                case .extension(let name):
                    fileNames.append(stem + "." + name)

                case .path(let path):
                    fileNames.append(path)
                }
            }
            
            for fname in fileNames
            {
                if let project = view.project
                {
                    let paths = project.resolve(fname)
                    for path in paths
                    {
                        app.open(path)
                    }
                }
                else
                {
                    let path = originalPath.popComponent().append(component: fname)
                    app.open(path)
                }
            }
        }

        return true
    }
    
    func findNames(_ path: MimsyPath) -> [Name]
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
        case `extension`(String)
        case path(String)
        
        static func parse(_ text: String) -> Name
        {
            return text.hasPrefix(".") ?
                .extension(text.substring(from: text.characters.index(text.startIndex, offsetBy: 1))) :
                .path(text)
        }
    }
    
    struct Mapping
    {
        let glob: MimsyGlob
        let names: [Name]
        
        init(_ app: MimsyApp, _ text: String)
        {
            var parts = text.components(separatedBy: " ")
            glob = app.globWithString(parts.removeFirst())
            names = parts.map {Name.parse($0)}
        }
    }
    
    var mappings: [Mapping] = []
}
