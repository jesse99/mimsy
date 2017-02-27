import Foundation
import Cocoa
import MimsyPlugins

class StdDefinitions: MimsyPlugin, MimsyDefinitions
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 0
        {
            definitionsPlugin = self
        }
        else if stage == 1
        {
            app.registerProject(.opened, onOpened)
            app.registerProject(.closing, onClosing)
            app.registerProject(.changed, onChanged)

//            app.registerWithSelectionTextContextMenu(.Lookup, callback: addLogItem)
        }
        else if (stage == 3)
        {
            findParsers(regexParsers)   // ordered thusly so if a later one has the same extension it will take precedence
            findParsers(parserParsers)
            findParsers(toolParsers)
            frozen = true
        }
        
        return nil
    }
    
    func findParsers(_ parsers: [ItemParser])
    {
        for parser in parsers
        {
            for name in parser.extensionNames
            {
                self.parsers[name] = parser
            }
        }
    }
    
    func addLogItem(_ view: MimsyTextView) -> [TextContextMenuItem]
    {
        if let project = view.project
        {
            return [TextContextMenuItem(title: "Log Definitions", invoke: {_ in
                self.dumpPaths("Declarations", self.declarations[project.path] ?? [:])
                self.dumpPaths("Definitions", self.definitions[project.path] ?? [:])
            })]
        }
        
        return []
    }
    
    func register(_ parser: ItemParser)
    {
        // The parser arrays are used from a thread so we don't want the main thread
        // changing them while the thread is using them.
        assert(!frozen)
        
        switch parser.method
        {
        case .regex: regexParsers.append(parser)
        case .parser: parserParsers.append(parser)
        case .externalTool: toolParsers.append(parser)
        }
    }
    
    func declarations(_ project: MimsyProject, name: String) -> [ItemPath]
    {
        return declarations[project.path]?[name] ?? []
    }
    
    func definitions(_ project: MimsyProject, name: String) -> [ItemPath]
    {
        return definitions[project.path]?[name] ?? []
    }
    
    func onOpened(_ project: MimsyProject)
    {
        projects[project.path] = ProjectInfo(modTime: 0.0, files: [:])
        startScanning(project)
    }
    
    // TODO: Could cache this data which would definitely help remote volumes (for samba
    // over VPN I am getting a pathetic 7 files/second even after tuning both this code
    // and the samba configuration).
    func onClosing(_ project: MimsyProject)
    {
        projects[project.path] = nil
        states[project.path] = nil
    }
    
    func onChanged(_ project: MimsyProject)
    {
        switch states[project.path]!
        {
        case .idle:
            startScanning(project)
        case .scanning:
            states[project.path] = .queued
        case .queued:
            break
        }
    }
    
    func startScanning(_ project: MimsyProject)
    {
        let root = project.path
        assert(states[root] ?? .idle != .scanning)
        states[root] = .scanning
        
        let concurrent = DispatchQueue.global(qos: .background)
        concurrent.async {self.scanProject(project, Date().timeIntervalSince1970)}
    }
    
    // Threaded code
    func scanProject(_ project: MimsyProject, _ startTime: TimeInterval)
    {
        func reportElapsed(_ count: Int)
        {
            if app.settings.boolValue("ReportElapsedTimes", missing: false)
            {
                let elapsed = Date().timeIntervalSince1970 - startTime
                app.transcript().writeLine(.plain, "Parsed %@ for definitions in %.1fs (%.2f files/sec)", project.path, elapsed, TimeInterval(count)/elapsed)
            }
        }
        
        var latestModTime = 0.0
        var newInfo: [MimsyPath: [ItemName]] = [:]

        let root = project.path
        
        var count = scanDir(&newInfo, &latestModTime, root, root)
        for dir in project.settings.stringValues("ExtraDirectory")
        {
            count += scanDir(&newInfo, &latestModTime, root, MimsyPath(withString: dir))
        }
        
        let (decs, defs) = buildPaths(newInfo)
        //        dumpPaths("Declarations", decs)
        //        dumpPaths("Definitions", defs)
        
        let main = DispatchQueue.main
        let delay = DispatchTime.now() + Double(Int64(0*NSEC_PER_MSEC)) / Double(NSEC_PER_SEC)
        main.asyncAfter(deadline: delay)
        {
            // Update the projects dictionary, but only if the project is still open.
            if let _ = self.projects[root]
            {
                self.projects[root] = ProjectInfo(modTime: latestModTime, files: newInfo)
                self.declarations[root] = decs
                self.definitions[root] = defs
//                reportElapsed(count)
                
                switch self.states[root]!
                {
                case .idle:
                    //assert(false)
                    break
                    
                case .scanning:
                    self.states[root] = .idle
                    
                case .queued:
                    self.startScanning(project)
                }
            }
        }
    }
    
    // Threaded code
    func scanDir(_ newInfo: inout [MimsyPath: [ItemName]], _ latestModTime: inout Double, _ root: MimsyPath, _ dir: MimsyPath) -> Int
    {
        let oldInfo = projects[root]
        var count = 0
        
        func shouldProcess(_ dir: MimsyPath, _ fileName: String) -> Bool
        {
            let path = dir.append(component: fileName)
            if let name = path.extensionName(), self.parsers.keys.contains(name)
            {
                do
                {
                    let mtime = try path.modTime()
                    latestModTime = max(mtime, latestModTime)
                    
                    switch oldInfo
                    {
                    case .some(let old):
                        if mtime > old.modTime
                        {
                            return true
                        }
                        else
                        {
                            newInfo[path] = old.files[path]
                        }
                        break
                    case .none:
                        return true
                    }
                }
                catch let err as NSError
                {
                    self.app.log("Plugins", "Failed to stat %@ when trying to parse definitions: %@", path, err.localizedFailureReason!)
                }
                catch
                {
                    self.app.log("Plugins", "Failed to stat %@ when trying to parse definitions: unknown error", path)
                }
            }
                
            return false
        }
    
        app.enumerate(dir: dir, recursive: true,
            error: {self.app.log("Plugins", "StdDefinitions error: %@", $0)},
            predicate: shouldProcess,
            callback: {(parent, fileNames) in
                do
                {
                    for fileName in fileNames
                    {
                        let name = (fileName as NSString).pathExtension
                        let path = parent.append(component: fileName)

                        let parser = self.parsers[name]!        // bang is safe because of the predicate above
                        newInfo[path] = try parser.parse(path)
                        count += 1
                    }
                }
                catch let err as NSError
                {
                    self.app.log("Plugins", "Failed to process %@ when trying to parse definitions: %@", parent, err.localizedFailureReason!)
                }
                catch
                {
                    self.app.log("Plugins", "Failed to process %@ when trying to parse definitions: unknown error", parent)
                }
            })
        
        return count
    }
        
    // Threaded code
    func buildPaths(_ infos: [MimsyPath: [ItemName]]) -> ([String: [ItemPath]], [String: [ItemPath]])
    {
        func add(_ namePaths: inout [String: [ItemPath]], _ name: String, _ path: ItemPath)
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
        
        for (path, items) in infos
        {
            for item in items
            {
                switch item
                {
                case .declaration(let name, let location):
                    add(&decs, name, ItemPath(path: path, location: location))
                case .definition(let name, let location):
                    add(&defs, name, ItemPath(path: path, location: location))
                }
            }
        }
        
        return (decs, defs)
    }
    
    // Threaded code
    func dumpPaths(_ kind: String, _ paths: [String: [ItemPath]])
    {
        if !paths.isEmpty
        {
            app.log("Plugins", "\(kind):")
            
            var entries: [String] = []
            for (name, items) in paths
            {
                let loc = (items.map {"\($0.path.lastComponent()):\($0.location)"}).joined(separator: ", ")
                entries.append("   \(name)  \(loc)")
            }
            
            entries.sort()
            
            for entry in entries
            {
                app.log("Plugins", "%@", entry)
            }
        }
    }
    
    enum State
    {
        case idle
        case scanning
        case queued
    }
    
    struct ProjectInfo
    {
        let modTime: Double
        let files: [MimsyPath: [ItemName]]  // file paths to definitions within that file
    }
    
    // Project path to name to definitions.
    typealias ProjectItemPaths = [MimsyPath: [String: [ItemPath]]]
    
    var toolParsers: [ItemParser] = []      // we use separate arrays for parsers to make prioritization easier
    var parserParsers: [ItemParser] = []    // note that, while these are var, they won't change after plugins finish loading
    var regexParsers: [ItemParser] = []
    var frozen = false
    
    var parsers: [String: ItemParser] = [:] // key is a file extension
    var states: [MimsyPath: State] = [:]
    var projects: [MimsyPath: ProjectInfo] = [:]    // key is a project root
    var declarations: ProjectItemPaths = [:]
    var definitions: ProjectItemPaths = [:]
}
