import Cocoa
import MimsyPlugins

class StdConvertToInt: MimsyPlugin
{
    override func onLoad(_ stage: Int) -> String?
    {
        if stage == 1
        {
            _ = app.addMenuItem(title: "Convert to Decimal", loc: .sorted, sel: "transformItems:", enabled: enabled, invoke: toDecimal)
            _ = app.addMenuItem(title: "Convert to Hex", loc: .sorted, sel: "transformItems:", enabled: enabled, invoke: toHex)
            
            app.registerWithSelectionTextContextMenu(.transform, callback: contextMenu)
        }
        
        return nil
    }
    
    func contextMenu(_ view: MimsyTextView) -> [TextContextMenuItem]
    {
        return [TextContextMenuItem(title: "Convert to Decimal", invoke: {_ in self.toDecimal()}),
            TextContextMenuItem(title: "Convert to Hex", invoke: {_ in self.toHex()})]
    }
    
    func enabled(_ item: NSMenuItem) -> Bool
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
    
    func toUTF8(_ text: String, format: String) -> String
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
    
    func toInt(_ text: String, radix: Int) -> Int?
    {
        var text = text
        if text.hasPrefix("0b")
        {
            return toInt(String(text.dropFirst(2)), radix: 2)
        }
        else if text.hasPrefix("0o")
        {
            return toInt(String(text.dropFirst(2)), radix: 8)
        }
        else if text.hasPrefix("0x")
        {
            return toInt(String(text.dropFirst(2)), radix: 16)
        }
        
        text = text.replacingOccurrences(of: "_", with: "")
        return Int(text, radix: radix)
    }
}
