import Cocoa

public typealias EnabledMenuItem = (NSMenuItem) -> Bool
public typealias InvokeMenuItem = () -> ()
public typealias TextViewCallback = (MimsyTextView) -> ()
public typealias TextViewKeyCallback = (MimsyTextView) -> Bool
public typealias ProjectContextMenuItemTitle = (_ files: [MimsyPath], _ dirs: [MimsyPath]) -> String?
public typealias InvokeProjectCommand = (_ files: [MimsyPath], _ dirs: [MimsyPath]) -> ()
public typealias TextRangeCallback = (MimsyTextView, NSRange) -> ()
public typealias ProjectCallback = (MimsyProject) -> ()
public typealias FilePredicate = (MimsyPath, String) -> Bool

public typealias InvokeTextCommand = (MimsyTextView) -> ()

open class TextContextMenuItem: NSObject
{
    public init(title: String, invoke: @escaping InvokeTextCommand)
    {
        self.title = title
        self.invoke = invoke
    }
    
    @objc public let title: String
    @objc public let invoke: InvokeTextCommand
}

public typealias TextContextMenuItemCallback = (MimsyTextView) -> [TextContextMenuItem]

@objc public enum MenuItemLoc: Int
{
    case before = 1, after, sorted
}

@objc public enum NoTextSelectionPos: Int
{
    case start = 1, middle, end
}

@objc public enum WithTextSelectionPos: Int
{
    case lookup = 1, transform, search, add
}

@objc public enum TextViewNotification: Int
{
    /// Invoked just before a text document is saved.
    case saving = 1
    
    /// Invoked after the selection has changed.
    case selectionChanged
    
    /// Invoked after language styling is applied.
    case appliedStyles
    
    /// Invoked just after a text document is opened.
    case opened
    
    /// Invoked just before a text document is closed.
    case closing
}

@objc public enum ProjectNotification: Int
{
    /// Invoked just after a project window is opened.
    case opened = 1
    
    /// Invoked just before a project window is closed.
    case closing
    
    /// Called when a file or directory within the project  is created, 
    /// removed, renamed, or modified. (These events are coalesced so for 
    /// something like a move there will only be one notification).
    case changed
}

/// This is used by plugins to communicate with the top level of Mimsy. 
@objc public protocol MimsyApp
{
    /// Contains settings for the app, but not for the current
    /// plugin or languages or projects.
    var settings: MimsySettings {get}
    
    /// Calls a block for each file in a directory.
    ///
    /// - Parameter dir: The directory that begins the enumeration.
    /// - Parameter recursive: If true then also process files in subdirectories of dir.
    /// - Parameter error: Called with an error message if a directory cannot be read.
    /// - Parameter predicate: Called with a directory and file name. Returns true if the file should be processed.
    /// - Parameter callback: Called with the full path of a directory and an array of non-hidden file names.
    func enumerate(dir: MimsyPath, recursive: Bool, error: (String) -> (), predicate: FilePredicate, callback: (MimsyPath, [String]) -> ())
    
    /// Typically the extension method will be used instead of this.
    func addNewMenuItem(_ item: NSMenuItem, loc: MenuItemLoc, sel: String, enabled: EnabledMenuItem?, invoke: @escaping InvokeMenuItem) -> Bool
    
    /// - Returns: If the frontmost window is a text document window then it is returned. Otherwise nil is returned.
    func textView() -> MimsyTextView?
    
    /// Returns an object that can be used to display status or error messages.
    func transcript() -> MimsyTranscript
    
    /// Registers a function that will be called when various project related events happen.
    func registerProject(_ kind: ProjectNotification, _ hook: @escaping ProjectCallback)
    
    /// Registers a function that will be called when various text view related events happen.
    func registerTextView(_ kind: TextViewNotification, _ hook: @escaping TextViewCallback)

    /// Used to register a function that will be called when a key is pressed. 
    ///
    /// - Parameter key: Currently the key may be: "clear", "delete", "down-arrow", "end", "enter", 
    /// "escape", "f<number>", "forward-delete" "help", "home", "left-arrow", "page-down", "page-up",
    /// "right-arrow", "tab", "up-arrow". The key may be preceded by one or more of the following
    /// modifiers: "command", "control", "option", "shift". If multiple modifiers are used they should
    /// be listed in alphabetical order, e.g. "option-shift-tab".
    /// - Parameter hook: Return true to suppress further processing of the key.
    func registerTextViewKey(_ key: String, _ identifier: String, _ hook: @escaping TextViewKeyCallback)
    
    /// Used to generate the Special Keys help file.
    ///
    /// - Parameter plugin: The name of the plugin, usually easiest to use bundle.bundleIdentifier!.
    /// - Parameter context: These are documented in Help Files. Contexts most often used include "app",
    /// "directory editor", "text editor", and language names (e.g. "python").
    /// - Parameter key: The name of the key, e.g. "Option-Shift-Tab".
    /// - Parameter description: What happens when the user presses the key.
    func addKeyHelp(_ plugin: String, _ context: String, _ key: String, _ description: String)

    /// Removes help added via addKeyHelp.
    func removeKeyHelp(_ plugin: String, _ context: String)

    /// Removes functions registered with registerTextViewKey. This is often used when the keys
    /// plugins use change as a result of the user editing a settings file.
    func clearRegisterTextViewKey(_ identifier: String)
        
    /// Used to register a function that will be called when a language style is applied.
    ///
    /// - Parameter element: The name of a language element, e.g. "Keyword", "Comment", "String", etc.
    /// "*" can also be used in which case the hook is called after a sequence of elements are styled.
    /// - Parameter hook: The function to call. This will often add new attributes to the range passed 
    /// into the hook.
    func registerApplyStyle(_ element: String, _ hook: @escaping TextRangeCallback)
    
    /// Used to add a custom menu item to the directory editor.
    ///
    /// - Parameter title: Returns the name of the new menu item, or nil if an item should not be added.
    /// Plugins should only add a menu item if they are able to process all the selected items.
    /// - Parameter invoke: Called when the user selects the new menu item.
    func registerProjectContextMenu(_ title: @escaping ProjectContextMenuItemTitle, invoke: @escaping InvokeProjectCommand)
    
    /// Used to add a custom menu item to text contextual menus when there is no selection.
    ///
    /// - Parameter pos: Pre-defined location at which to insert the new sorted menu item.
    /// - Parameter title: Returns the name of the new menu item, or nil if an item should not be added.
    /// - Parameter invoke: Called when the user selects the new menu item.
    func registerNoSelectionTextContextMenu(_ pos: NoTextSelectionPos, callback: @escaping TextContextMenuItemCallback)
    
    /// Used to add a custom menu item to text contextual menus when is a selection.
    ///
    /// - Parameter pos: Pre-defined location at which to insert the new sorted menu item.
    /// - Parameter title: Returns the name of the new menu item, or nil if an item should not be added.
    /// - Parameter invoke: Called when the user selects the new menu item.
    func registerWithSelectionTextContextMenu(_ pos: WithTextSelectionPos, callback: @escaping TextContextMenuItemCallback)
    
    /// Returns the environment variables Mimsy was launched with (which are normally a subset
    /// of the variables the shell commands receive) augmented with Mimsy settings (e.g. to append
    /// more paths onto PATH). This is the environment that should be used when using NSTask.
    func environment() -> [String: String]
    
    /// Returns a color from a name where the name may be a CSS3 color name ("Dark Green"), a VIM 7.3 
    /// name ("gray50"), hex RGB or RGBA numbers ("#FF0000" or "#FF0000FF"), or decimal RGB or RGBA
    /// tuples ("(255, 0, 0)" or "(255, 0, 0, 255)"). Names are lower cased and spaces are stripped.
    func mimsyColor(_ name: String) -> NSColor?
    
    /// Opens a file with Mimsy where possible and as if double-clicked within the Finder otherwise.
    ///
    /// - Parameter path: Full path to a file.
    func open(_ path: MimsyPath)
    
    /// Opens a file with Mimsy where possible and as if double-clicked within the Finder otherwise.
    ///
    /// - Parameter path: Full path to a file.
    /// - Parameter withRange: Range of text to select and scroll into view.
    func open(_ path: MimsyPath, withRange: NSRange)
    
    /// Opens a file as raw binary and display the contents as hex and ASCII.
    ///
    /// - Parameter path: Full path to a file.
    func openAsBinary(_ path: MimsyPath)
        
    /// Typically the extension method will be used instead of this.
    func logString(_ topic: String, text: String)

    /// Create a glob using one pattern.
    func globWithString(_ glob: String) -> MimsyGlob
    
    /// Create a glob using multiple patterns.
    func globWithStrings(_ globs: [String]) -> MimsyGlob

    /// Uses the file's extension (and possibly shebang) to try and find a language associated with the file.
    func findLanguage(_ path: MimsyPath) -> MimsyLanguage?

    func languages() -> [MimsyLanguage]
    
    func _modTime(_ path: MimsyPath) throws -> NSNumber
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
    public func addMenuItem(_ item: NSMenuItem? = nil, title: String? = nil, loc: MenuItemLoc, sel: String, enabled: EnabledMenuItem? = nil, invoke: @escaping InvokeMenuItem) -> Bool
    {
        let theItem = item != nil ? item! : NSMenuItem(title: title!, action: nil, keyEquivalent: "")
        return addNewMenuItem(theItem, loc: loc, sel: sel, enabled: enabled, invoke: invoke)
    }
    
    /// Depending upon whether the logging.mimsy settings file enables the topic
    /// this will add a new log line to Mimsy's log. Note that the log is normally
    /// at ~/Library/Logs/mimsy.log.
    ///
    /// - Parameter topic: Typically "Plugins", "Plugins:Verbose", or a custom topic name.
    /// - Parameter format: NSString style [format string](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/Strings/Articles/formatSpecifiers.html).
    /// - Parameter args: Optional arguments to feed into the format string.
    public func log(_ topic: String, _ format: String, _ args: CVarArg...)
    {
        let text = String(format: format, arguments: args)
        logString(topic, text: text)
    }
    
    /// Returns the full path to an executable or nil.
    public func findExe(_ name: String) -> String?
    {
        let pipe = Pipe()
        
        let task = Process()
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
            result = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String?
            result = result?.trimmingCharacters(in: CharacterSet.newlines)
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
        
        if let rpath = Bundle.main.resourcePath
        {
            let path = MimsyPath(withString: rpath).append(component: "UnicodeNames.zip")
            if let unzip = findExe("unzip")
            {
                let contents = unzipFile(unzip, path)
                names = contents.components(separatedBy: "\n")
            }
        }
        
        return names
    }
    
    func unzipFile(_ tool: String, _ path: MimsyPath) -> String
    {
        let pipe = Pipe()
        
        let task = Process()
        task.launchPath = tool
        task.arguments = ["-p", path.asString()]
        task.standardOutput = pipe
        
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
    }
}

var unicodeNames: [String]?
var app: MimsyApp?

