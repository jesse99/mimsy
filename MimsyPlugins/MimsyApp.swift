import Cocoa

public typealias EnabledMenuItem = (NSMenuItem) -> Bool
public typealias InvokeMenuItem = () -> ()
public typealias InvokeTextCommand = (MimsyTextView) -> ()
public typealias SavingTextDoc = (MimsyTextView) -> ()
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

/// This is used by plugins to communicate with the top level of Mimsy.
@objc public protocol MimsyApp
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
    func addMenuItem(item: NSMenuItem, loc: MenuItemLoc, sel: String, enabled: EnabledMenuItem?, invoke: InvokeMenuItem) -> Bool

    /// Like addMenuItem except that it takes the title of the new menu item instead of a menu item.
    func addMenuItemTitled(title: String, loc: MenuItemLoc, sel: String, enabled: EnabledMenuItem?, invoke: InvokeMenuItem) -> Bool
    
    /// - Returns: The text view for the frontmost document window.
    func frontTextView() -> MimsyTextView?
    
    /// Registers a function that will be called just before a save.
    func registerOnSave(hook: SavingTextDoc)
    
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
    
    // Returns the environment variables Mimsy was launched with (which are normally a subset
    // of the variables the shell commands receive) augmented with Mimsy settings (e.g. to append
    // more paths onto PATH). This is the environment that should be used when using NSTask.
    func environment() -> [String: String]
    
    /// Normally plugins will use the MimsyPlugin log method instead of this.
    func logLine(topic: String, text: String)
}
