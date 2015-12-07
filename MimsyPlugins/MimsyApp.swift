import Cocoa

public typealias EnabledMenuItem = (NSMenuItem) -> Bool
public typealias InvokeMenuItem = () -> ()
public typealias InvokeTextCommand = (MimsyTextView) -> ()
public typealias TextViewCallback = (MimsyTextView) -> ()
public typealias TextViewKeyCallback = (MimsyTextView) -> Bool
public typealias TextContextMenuItemTitle = (MimsyTextView) -> String?

@objc public enum MenuItemLoc: Int
{
    case Before = 1, After, Sorted
}

@objc public enum NoTextSelectionPos: Int
{
    case Start = 1, Middle, End
}

@objc public enum WithTextSelectionPos: Int
{
    case Lookup = 1, Transform, Search, Add
}

@objc public enum TextViewNotification: Int
{
    /// Invoked just before a text document is saved.
    case Saving = 1
    
    /// Invoked after the selection has changed.
    case SelectionChanged
    
    /// Invoked after language styling is applied.
    case AppliedStyles
}

// TODO: Once we can call static protocol methods from within swift we can
// clean some of this up, e.g. text view registration, glob creation, etc.
// See

/// This is used by plugins to communicate with the top level of Mimsy.
@objc public protocol MimsyApp
{
    /// Typically the extension method will be used instead of this.
    func addMenuItem(item: NSMenuItem, loc: MenuItemLoc, sel: String, enabled: EnabledMenuItem?, invoke: InvokeMenuItem) -> Bool
    
    /// - Returns: If the frontmost window is a text document window then it is returned. Otherwise nil is returned.
    func textView() -> MimsyTextView?
    
    /// Returns an object that can be used to display status or error messages.
    func transcript() -> MimsyTranscript
    
    /// Registers a function that will be called just before a save.
    func registerTextView(kind: TextViewNotification, _ hook: TextViewCallback)

    /// Used to register a function that will be called when a key is pressed. 
    ///
    /// - Parameter key: Currently the key may be: "clear", "delete", "down-arrow", "end", "enter", 
    /// "escape", "f<number>", "forward-delete" "help", "home", "left-arrow", "page-down", "page-up",
    /// "right-arrow", "tab", "up-arrow". The key may be preceded by one or more of the following
    /// modifiers: "command", "control", "option", "shift". If multiple modifiers are used they should
    /// be listed in alphabetical order, e.g. "option-shift-tab".
    /// - Parameter hook: Return true to suppress further processing of the key.
    func registerTextViewKey(key: String, _ identifier: String, _ hook: TextViewKeyCallback)

    /// Removes functions registered with registerTextViewKey. This is often used when the keys
    /// plugins use change as a result of the user editing a settings file.
    func clearRegisterTextViewKey(identifier: String)
    
    /// Used to add a custom menu item to text contextual menus when there is no selection.
    ///
    /// - Parameter pos: Pre-defined location at which to insert the new sorted menu item.
    /// - Parameter name: Returns the name of the new menu item, or nil if an item should not be added.
    /// - Parameter invoke: Called when the user selects the new menu item.
    func registerNoSelectionTextContextMenu(pos: NoTextSelectionPos, title: TextContextMenuItemTitle, invoke: InvokeTextCommand)
    
    /// Used to add a custom menu item to text contextual menus when is a selection.
    ///
    /// - Parameter pos: Pre-defined location at which to insert the new sorted menu item.
    /// - Parameter name: Returns the name of the new menu item, or nil if an item should not be added.
    /// - Parameter invoke: Called when the user selects the new menu item.
    func registerWithSelectionTextContextMenu(pos: WithTextSelectionPos, title: TextContextMenuItemTitle, invoke: InvokeTextCommand)
    
    /// Returns the environment variables Mimsy was launched with (which are normally a subset
    /// of the variables the shell commands receive) augmented with Mimsy settings (e.g. to append
    /// more paths onto PATH). This is the environment that should be used when using NSTask.
    func environment() -> [String: String]
    
    /// Returns a color from a name where the name may be a CSS3 color name ("Dark Green"), a VIM 7.3 
    /// name ("gray50"), hex RGB or RGBA numbers ("#FF0000" or "#FF0000FF"), or decimal RGB or RGBA
    /// tuples ("(255, 0, 0)" or "(255, 0, 0, 255)"). Names are lower cased and spaces are stripped.
    func mimsyColor(name: String) -> NSColor?
    
    /// Opens a file with Mimsy where possible and as if double-clicked within the Finder otherwise.
    ///
    /// - Parameter path: Full path to a file.
    func open(path: String)
        
    /// Typically the extension method will be used instead of this.
    func logString(topic: String, text: String)

    /// Create a glob using one pattern.
    func globWithString(glob: String) -> MimsyGlob
    
    /// Create a glob using multiple patterns.
    func globWithStrings(globs: [String]) -> MimsyGlob
}

public extension MimsyApp
{
    /// Adds a new menu item to Mimsy's menubar.
    ///
    /// There are a few standard locations that plugins will often want to use when adding
    /// menu items. These are often hidden menu items. Commonly used selectors include:
    /// - **getInfo:**             File menu, used to show information about the current document.
    /// - **showItems:**           Text menu, used to toggle showing things like whitespace.
    /// - **transformItems:**      Text menu, used to change the current selection, e.g. to change case.
    /// - **underline:**           Format menu, used to change text formatting.
    /// - **find:,
    ///     findNext:,
    ///     findPrevious:**        Search menu, finding text within the current document.
    /// - **findInFiles:,
    ///     findNextInFiles:,
    ///     findPreviousInFiles:** Search menu, finding text within a directory.
    /// - **jumpToLine:**          Search menu, navigating within the current document.
    /// - **build:**               Build menu, build the current target.
    /// - **showHelp:**            Help menu, text or html files with help.
    ///
    /// - Parameter item: The menu item to add. Note that plugins should not use representedObject.
    /// - Parameter loc: Controls whether the new menu item is added before sel, after sel, or so that the menu items around sel are kept sorted.
    /// - Parameter sel: A selector from one of Mimsy's menu items (see above for more details).
    /// - Parameter enabled: If set then this will point to a function which can be used to enable and disable the menu item (or change the title or change the state (to add checkmarks)). If not set then the item is always enabled.
    /// - Parameter invoke: The function to invoke when the menu item is selected.
    ///
    /// - Returns: True if menu item was added. False if sel could not be found.
    public func addMenuItem(item: NSMenuItem? = nil, title: String? = nil, loc: MenuItemLoc, sel: String, enabled: EnabledMenuItem? = nil, invoke: InvokeMenuItem) -> Bool
    {
        let theItem = item != nil ? item! : NSMenuItem(title: title!, action: "", keyEquivalent: "")
        return addMenuItem(theItem, loc: loc, sel: sel, enabled: enabled, invoke: invoke)
    }
    
    /// Depending upon whether the logging.mimsy settings file enables the topic
    /// this will add a new log line to Mimsy's log. Note that the log is normally
    /// at ~/Library/Logs/mimsy.log.
    ///
    /// - Parameter topic: Typically "Plugins", "Plugins:Verbose", or a custom topic name.
    /// - Parameter format: NSString style [format string](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/Strings/Articles/formatSpecifiers.html).
    /// - Parameter args: Optional arguments to feed into the format string.
    public func log(topic: String, _ format: String, _ args: CVarArgType...)
    {
        let text = String(format: format, arguments: args)
        logString(topic, text: text)
    }
    
    /// Returns the full path to an executable or nil.
    public func findExe(name: String) -> String?
    {
        let pipe = NSPipe()
        
        let task = NSTask()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "which \(name)"]
        task.environment = environment()
        task.standardOutput = pipe
        
        task.launch()
        task.waitUntilExit()
        
        var result: String? = nil
        if task.terminationStatus == 0
        {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            result = NSString(data: data, encoding: NSUTF8StringEncoding) as String?
            result = result?.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
        }
        
        return result
    }
    
    /// Returns a list of Unicode names indexed by code point. Names are things like 
    /// "NOT EQUAL TO" or "-" for an invalid code point.
    public func getUnicodeNames() -> [String]
    {
        // Only load the names once.
        if unicodeNames == nil
        {
            unicodeNames = loadUnicodeNames()
        }
        
        return unicodeNames!
    }
    
    func loadUnicodeNames() -> [String]
    {
        var names = [String]()
        
        var path = NSBundle.mainBundle().resourcePath as NSString?
        path = path?.stringByAppendingPathComponent("UnicodeNames.zip")
        if let path = path, unzip = findExe("unzip")
        {
            let contents = unzipFile(unzip, path)
            names = contents.componentsSeparatedByString("\n")
        }
        
        return names
    }
    
    func unzipFile(tool: String, _ path: NSString) -> String
    {
        let pipe = NSPipe()
        
        let task = NSTask()
        task.launchPath = tool
        task.arguments = ["-p", path as String]
        task.standardOutput = pipe
        
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return NSString(data: data, encoding: NSUTF8StringEncoding) as String!
    }
}

var unicodeNames: [String]?
