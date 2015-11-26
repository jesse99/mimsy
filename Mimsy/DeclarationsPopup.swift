
import Foundation

class DeclarationsPopup : NSPopUpButton
{
    required init?(coder: NSCoder)
    {
        _decs = [Declaration]()
        super.init(coder: coder)
    }
    
    override func mouseDown(theEvent: NSEvent)
    {
        if theEvent.modifierFlags.rawValue & NSEventModifierFlags.AlternateKeyMask.rawValue != 0
        {
            sortItems{$0.name < $1.name || ($0.name == $1.name && $0.range.location < $1.range.location)}
            super.mouseDown(theEvent)
            sortItems{$0.range.location < $1.range.location}
        }
        else
        {
            super.mouseDown(theEvent)
        }
    }
    
    func onAppliedStyles(view: NSTextView)
    {
        _decs = [Declaration]()
        _view = view
        
        let str = view.textStorage
        let text: NSString = str!.string
        str?.enumerateAttribute("element name", inRange: NSMakeRange(0, str!.length), options: [], usingBlock: { (value, range, stop) -> Void in
            if let name = value as? NSString
            {
                let prefix = self.findIndent(text, range: range)
                let title = prefix + text.substringWithRange(range)
                
                if name == "function"
                {
                    self._decs.append(Declaration(name: title, range: range, isType: false))
                }
                else if name == "structure"
                {
                    self._decs.append(Declaration(name: title, range: range, isType: true))
                }
            }
        })
        
        self.resetItems(_decs)
        self.onSelectionChanged(view)
    }
    
    func onSelectionChanged(view: NSTextView)
    {
       let range = view.selectedRange()
        
        for (i, dec) in self._decs.enumerate()
        {
            if range.location >= dec.range.location && (i+1 == self._decs.count || range.location < self._decs[i+1].range.location)
            {
                self.selectItemAtIndex(i)
                return
            }
        }

        self.selectItemAtIndex(-1)
    }
    
    func onSelectItem(sender: NSMenuItem)
    {
        let range = sender.representedObject as! NSRange
        
        _view!.setSelectedRange(range)
        _view!.scrollRangeToVisible(range)
        _view!.showFindIndicatorForRange(range)
    }
    
    // TODO: May want to add a Member style. Then we could indent if it's not already indented.
    private func findIndent(text: NSString, range: NSRange) -> String
    {
        var i = range.location
        while i > 0 && text.characterAtIndex(i-1) != 0x0D && text.characterAtIndex(i-1) != 0x0A
        {
            --i
        }
        
        var count = 0
        while i + count < text.length
        {
            let c = text.characterAtIndex(i + count)
            if c == 0x20
            {
                count += 1
            }
            else if c == 0x09
            {
                count += 3
            }
            else
            {
                break
            }
        }
        
        let c = Character(" ")
        return String(count: count, repeatedValue: c)
    }
    
    private func sortItems(by: (lhs: Declaration, rhs: Declaration) -> Bool)
    {
        let decs1 = _decs.sort(by)
        self.resetItems(decs1)
   }
    
    private func resetItems(decs: [Declaration])
    {
        // popup menu item names must be unique but declarations may not be (e.g. for languages with overloading)
        // so we'll append some invisible spaces to the end of each name
        let c = Character(ZeroWidthSpaceChar)
        let decs2 = decs.mapi { (index, dec) -> Declaration in
            let suffix = String(count: index, repeatedValue: c)
            return Declaration(name: dec.name + suffix, range: dec.range, isType: dec.isType)
        }

        self.removeAllItems()
        for dec in decs2
        {
            self.addItemWithTitle(dec.name)

            var attrs = [String: AnyObject]()
            attrs[NSFontAttributeName] = NSFont.systemFontOfSize(NSFont.smallSystemFontSize())
            if dec.isType
            {
                attrs[NSStrokeWidthAttributeName] = -4.0
            }
            
            let item = self.lastItem
            item!.attributedTitle = NSAttributedString(string: dec.name, attributes: attrs)
            item!.representedObject = dec.range
            item!.target = self
            item!.action = "onSelectItem:"
        }
    }
    
    private struct Declaration
    {
        let name: String
        let range: NSRange
        let isType: Bool
    }
    
    private var _view: NSTextView?
    private var _decs: [Declaration]
}