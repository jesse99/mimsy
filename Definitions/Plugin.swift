import Foundation
import Cocoa
import MimsyPlugins

class StdDefinitions: MimsyPlugin, MimsyDefinitions
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 0
        {
            definitions = self
        }
        else if stage == 1
        {
            app.registerProject(.Opened, onOpened)
            app.registerProject(.Closing, onClosing)
            app.registerProject(.Changed, onChanged)
            
            // TODO: maybe we want yet another plugin to assemble the context menu items
//            app.registerWithSelectionTextContextMenu(.Transform, title: {_ in
//                "Escape HTML"}, invoke: { _ in self.html()})
//            app.registerWithSelectionTextContextMenu(.Transform, title: {_ in
//                "Escape XML"}, invoke: { _ in self.xml()})
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
    
    func onOpened(project: MimsyProject)
    {
        projects[project.path] = [:]
        
        // TODO: may want to do this only if we have a parser
        let concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
        dispatch_async(concurrent) {self.scan(project.path)}
    }
    
    func onClosing(project: MimsyProject)
    {
        projects[project.path] = nil
    }
    
    func onChanged(project: MimsyProject)
    {
        // TODO: what if one is in progress? probably defer using a flag
        // TODO: may want to do this only if we have a parser
        let concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
        dispatch_async(concurrent) {self.scan(project.path)}
    }
    
    // Threaded code
    func scan(root: MimsyPath)
    {
        var paths: [MimsyPath: PathInfo] = [:]
        let oldPaths = projects[root]
        
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
                        
                        if let oldInfo = oldPaths?[path]
                        {
                            if currentDate.compare(oldInfo.date) == .OrderedDescending
                            {
                                paths[path] = PathInfo(date: currentDate, items: try parse(path))
                            }
                            else
                            {
                                paths[path] = oldInfo
                            }
                        }
                        else
                        {
                            paths[path] = PathInfo(date: currentDate, items: try parse(path))
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
        
        // TODO: probably want to compute names here
        
        let main = dispatch_get_main_queue()
        let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(0*NSEC_PER_MSEC))
        dispatch_after(delay, main)
        {
            // Update the projects dictionary, but only if the project is still open.
            if let _ = self.projects[root]
            {
                self.projects[root] = paths
            }
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
    
    // TODO:
    // context menu logic needs to use the right project
    // should be able to use additional directories (open selection should also use those)
//    func enabled(item: NSMenuItem) -> Bool
//    {
//        var enabled = false
//        
//        if let view = app.textView()
//        {
//            enabled = view.selectionRange.length > 0
//        }
//        
//        return enabled
//    }
//    
//    func html()
//    {
//        if let view = app.textView()
//        {
//            var text = view.selection
//            text = text.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
//            text = text.stringByReplacingOccurrencesOfString("<", withString: "&lt;")
//            text = text.stringByReplacingOccurrencesOfString(">", withString: "&gt;")
//            text = text.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
//            view.setSelection(text, undoText: "Escape HTML")
//        }
//    }
//    
//    func xml()
//    {
//        if let view = app.textView()
//        {
//            var text = view.selection
//            text = text.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
//            text = text.stringByReplacingOccurrencesOfString("<", withString: "&lt;")
//            text = text.stringByReplacingOccurrencesOfString(">", withString: "&gt;")
//            text = text.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
//            text = text.stringByReplacingOccurrencesOfString("'", withString: "&apos;")
//            view.setSelection(text, undoText: "Escape XML")
//        }
//    }
    
    struct PathInfo
    {
        let date: NSDate
        let items: [ItemName]
    }
    
    // Project path to file path to definitions within that file
    typealias ProjectItemNames = [MimsyPath: [MimsyPath: PathInfo]]
    
    var toolParsers: [ItemParser] = []      // we use separate arrays for parsers to make priorization easier
    var parserParsers: [ItemParser] = []    // note that, while these are var, they won't change after plugins finish loading
    var regexParsers: [ItemParser] = []
    var frozen = false
    
    var projects: ProjectItemNames = [:]
}
