import Cocoa

public typealias InvokeMenuItem = () -> ()
public typealias EnabledMenuItem = (NSMenuItem) -> Bool
public typealias OnSaving = (MimsyTextView) -> ()

@objc public enum MenuItemLoc: Int
{
    case Before = 1, After, Sorted
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
    
    /// - Returns: The text view for the frontmost document window.
    func frontTextView() -> MimsyTextView?
    
    /// Registers a function that will be called just before text documents are saved.
    func registerOnSaving(hook: OnSaving)
    
    /// Normally plugins will use the MimsyPlugin log method instead of this.
    func logLine(topic: String, text: String)
}
