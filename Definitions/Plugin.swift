import Foundation
import Cocoa
import MimsyPlugins

class StdDefinitions: MimsyPlugin, MimsyDefinitions
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 0
        {
            definitionsPlugin = self
        }
        else if stage == 1
        {
            app.registerProject(.Opened, onOpened)
            app.registerProject(.Closing, onClosing)
            app.registerProject(.Changed, onChanged)
        }
        else if (stage == 3)
        {
            frozen = true
        }
        
        return nil
    }
    
    func register(parser: ItemParser)
    {
        // The parser arrays are used from a thread so we don't want the main thread
        // changing them while the thread is using them.
        assert(!frozen)
        
        switch parser.method
        {
        case .Regex: regexParsers.append(parser)
        case .Parser: parserParsers.append(parser)
        case .ExternalTool: toolParsers.append(parser)
        }
    }
    
    func declarations(project: MimsyProject, name: String) -> [ItemPath]
    {
        return declarations[project.path]?[name] ?? []
    }
    
    func definitions(project: MimsyProject, name: String) -> [ItemPath]
    {
        return definitions[project.path]?[name] ?? []
    }
    
    func onOpened(project: MimsyProject)
    {
        projects[project.path] = [:]
        startScanning(project.path)
    }
    
    func onClosing(project: MimsyProject)
    {
        projects[project.path] = nil
        states[project.path] = nil
    }
    
    func onChanged(project: MimsyProject)
    {
        switch states[project.path]!
        {
        case .Idle:
            startScanning(project.path)
        case .Scanning:
            states[project.path] = .Queued
        case .Queued:
            break
        }
    }
    
    func startScanning(root: MimsyPath)
    {
        assert(states[root] ?? .Idle != .Scanning)
        states[root] = .Scanning
        
        let concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
        dispatch_async(concurrent) {self.scan(root)}
    }
    
    // Threaded code
    func scan(root: MimsyPath)
    {
        var pathInfos: [MimsyPath: ItemsInfo] = [:]
        let oldPathInfos = projects[root]
        
        let fm = NSFileManager.defaultManager()
        let keys = [NSURLIsDirectoryKey, NSURLPathKey, NSURLContentModificationDateKey]
        if let enumerator = fm.enumeratorAtURL(root.asURL(), includingPropertiesForKeys: keys, options: .SkipsHiddenFiles, errorHandler:
        {(url, err) -> Bool in
            self.app.log("Plugins", "Failed to enumerate %@ when trying to parse definitions: %@", url, err)
            return true
        })
        {
            for element in enumerator
            {
                let url = element as! NSURL
                
                do
                {
                    if try !url.isDirectoryValue()
                    {
                        let path = try url.pathValue()
                        let currentDate = try url.contentModificationDateValue()
                        
                        if let oldPathInfo = oldPathInfos?[path]
                        {
                            if currentDate.compare(oldPathInfo.date) == .OrderedDescending
                            {
                                pathInfos[path] = ItemsInfo(date: currentDate, items: try parse(path))
                            }
                            else
                            {
                                pathInfos[path] = oldPathInfo
                            }
                        }
                        else
                        {
                            pathInfos[path] = ItemsInfo(date: currentDate, items: try parse(path))
                        }
                    }
                }
                catch let err as NSError
                {
                    self.app.log("Plugins", "Failed to process %@ when trying to parse definitions: %@", url, err.localizedFailureReason!)
                }
                catch
                {
                    self.app.log("Plugins", "Failed to process %@ when trying to parse definitions: unknown error", url)
                }
           }
        }
        
        let (decs, defs) = buildPaths(pathInfos)
//        dumpPaths("Declarations", decs)
//        dumpPaths("Definitions", defs)
        
        let main = dispatch_get_main_queue()
        let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(0*NSEC_PER_MSEC))
        dispatch_after(delay, main)
        {
            // Update the projects dictionary, but only if the project is still open.
            if let _ = self.projects[root]
            {
                self.projects[root] = pathInfos
                self.declarations[root] = decs
                self.definitions[root] = defs

                switch self.states[root]!
                {
                case .Idle:
                    assert(false)
                    
                case .Scanning:
                    self.states[root] = .Idle
                    
                case .Queued:
                    self.startScanning(root)
                }
            }
        }
    }
    
    // Threaded code
    func dumpPaths(kind: String, _ paths: [String: [ItemPath]])
    {
        app.log("Plugins", "\(kind):")
        
        var entries: [String] = []
        for (name, items) in paths
        {
            let loc = (items.map {"\($0.path.lastComponent()):\($0.location)"}).joinWithSeparator(", ")
            entries.append("   \(name)  \(loc)")
        }
        
        entries.sortInPlace()
        
        for entry in entries
        {
            app.log("Plugins", "%@", entry)
        }
    }
    
    // Threaded code
    func parse(path: MimsyPath) throws -> [ItemName]
    {
        func _parse(candidates: [ItemParser], _ path: MimsyPath) throws -> [ItemName]?
        {
            for parser in candidates
            {
                if let items = try parser.tryParse(path)
                {
                    return items
                    
                }
            }
            
            return nil
        }
        
        return try _parse(toolParsers, path) ?? _parse(parserParsers, path) ?? _parse(regexParsers, path) ?? []
    }
    
    // Threaded code
    func buildPaths(infos: [MimsyPath: ItemsInfo]) -> ([String: [ItemPath]], [String: [ItemPath]])
    {
        func add(inout namePaths: [String: [ItemPath]], _ name: String, _ path: ItemPath)
        {
            if var paths = namePaths[name]
            {
                paths.append(path)
                namePaths[name] = paths
            }
            else
            {
                namePaths[name] = [path]
            }
        }
        
        var decs: [String: [ItemPath]] = [:]
        var defs: [String: [ItemPath]] = [:]
        
        for (path, info) in infos
        {
            for item in info.items
            {
                switch item
                {
                case .Declaration(let name, let location):
                    add(&decs, name, ItemPath(path: path, location: location))
                case .Definition(let name, let location):
                    add(&defs, name, ItemPath(path: path, location: location))
                }
            }
        }
        
        return (decs, defs)
    }
    
    enum State
    {
        case Idle
        case Scanning
        case Queued
    }
    
    struct ItemsInfo
    {
        let date: NSDate
        let items: [ItemName]
    }
    
    // Project path to file path to definitions within that file
    typealias ProjectItemNames = [MimsyPath: [MimsyPath: ItemsInfo]]

    // Project path to name to definitions.
    typealias ProjectItemPaths = [MimsyPath: [String: [ItemPath]]]
    
    var toolParsers: [ItemParser] = []      // we use separate arrays for parsers to make prioritization easier
    var parserParsers: [ItemParser] = []    // note that, while these are var, they won't change after plugins finish loading
    var regexParsers: [ItemParser] = []
    var frozen = false
    
    var states: [MimsyPath: State] = [:]
    var projects: ProjectItemNames = [:]
    var declarations: ProjectItemPaths = [:]
    var definitions: ProjectItemPaths = [:]
}
