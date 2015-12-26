import Cocoa
import MimsyPlugins

class StdConvertToInt: MimsyPlugin
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            app.addMenuItem(title: "Convert to Decimal", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: toDecimal)
            app.addMenuItem(title: "Convert to Hex", loc: .Sorted, sel: "transformItems:", enabled: enabled, invoke: toHex)
            
            app.registerWithSelectionTextContextMenu(.Transform, callback: contextMenu)
        }
        
        return nil
    }
    
    func contextMenu(view: MimsyTextView) -> [TextContextMenuItem]
    {
        return [TextContextMenuItem(title: "Convert to Decimal", invoke: {_ in self.toDecimal()}),
            TextContextMenuItem(title: "Convert to Hex", invoke: {_ in self.toHex()})]
    }
    
    func enabled(item: NSMenuItem) -> Bool
    {
        var enabled = false
        
        if let view = app.textView()
        {
            enabled = view.selectionRange.length > 0
        }
        
        return enabled
    }
    
    func toDecimal()
    {
        if let view = app.textView()
        {
            let text = view.selection

            var newText = ""
            if let n = toInt(text, radix: 16)
            {
                newText = String(format: "%d", arguments: [n])
            }
            else
            {
                newText = toUTF8(text, format: "%d")
            }
            view.setSelection(newText, undoText: "Convert to Decimal")
        }
    }
    
    func toHex()
    {
        if let view = app.textView()
        {
            let text = view.selection
            
            var newText = ""
            if let n = toInt(text, radix: 10)
            {
                newText = String(format: "%02X", arguments: [n])
            }
            else
            {
                newText = toUTF8(text, format: "%02X")
            }
            view.setSelection(newText, undoText: "Convert to Hex")
        }
    }
    
    func toUTF8(text: String, format: String) -> String
    {
        var newText = ""

        for ch in text.utf8
        {
            if !newText.isEmpty
            {
                newText += " "
            }
            newText += String(format: format, arguments: [ch])
        }
        
        return newText
    }
    
    func toInt(var text: String, radix: Int) -> Int?
    {
        if text.hasPrefix("0b")
        {
            text.removeRange(text.startIndex ..< text.startIndex.advancedBy(2))
            return toInt(text, radix: 2)
        }
        else if text.hasPrefix("0o")
        {
            text.removeRange(text.startIndex ..< text.startIndex.advancedBy(2))
            return toInt(text, radix: 8)
        }
        else if text.hasPrefix("0x")
        {
            text.removeRange(text.startIndex ..< text.startIndex.advancedBy(2))
            return toInt(text, radix: 16)
        }
        
        text = text.stringByReplacingOccurrencesOfString("_", withString: "")
        return Int(text, radix: radix)
    }
}
