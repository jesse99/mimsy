
import Foundation

class DeclarationsPopup : NSPopUpButton
{
    required init?(coder: NSCoder)
    {
        _decs = [Declaration]()
        super.init(coder: coder)
    }
    
    override func mouseDown(with theEvent: NSEvent)
    {
        if theEvent.modifierFlags.rawValue & NSEventModifierFlags.option.rawValue != 0
        {
            sortItems{let d0 = $0; return d0.name < $1.name || (d0.name == $1.name && d0.range.location < $1.range.location)}
            super.mouseDown(with: theEvent)
            sortItems{$0.range.location < $1.range.location}
        }
        else
        {
            super.mouseDown(with: theEvent)
        }
    }
    
    func onAppliedStyles(_ view: NSTextView)
    {
        _decs = [Declaration]()
        _view = view
        
        let str = view.textStorage
        let text: NSString = str!.string as NSString
        str?.enumerateAttribute("element name", in: NSMakeRange(0, str!.length), options: [], using: { (value, range, stop) -> Void in
            if let name = value as? NSString
            { 
                let prefix = self.findIndent(text, range: range)
                let title = prefix + text.substring(with: range)
                
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
    
    func onSelectionChanged(_ view: NSTextView)
    {
       let range = view.selectedRange()
        
        for (i, dec) in self._decs.enumerated()
        {
            if range.location >= dec.range.location && (i+1 == self._decs.count || range.location < self._decs[i+1].range.location)
            {
                self.selectItem(at: i)
                return
            }
        }

        self.selectItem(at: -1)
    }
    
    func onSelectItem(_ sender: NSMenuItem)
    {
        let range = sender.representedObject as! NSRange
        
        _view!.setSelectedRange(range)
        _view!.scrollRangeToVisible(range)
        _view!.showFindIndicator(for: range)
    }
    
    // TODO: May want to add a Member style. Then we could indent if it's not already indented.
    fileprivate func findIndent(_ text: NSString, range: NSRange) -> String
    {
        var i = range.location
        while i > 0 && text.character(at: i-1) != 0x0D && text.character(at: i-1) != 0x0A
        {
            i -= 1
        }
        
        var count = 0
        while i + count < text.length
        {
            let c = text.character(at: i + count)
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
        return String(repeating: String(c), count: count)
    }
    
    fileprivate func sortItems(_ by: (_ lhs: Declaration, _ rhs: Declaration) -> Bool)
    {
        let decs1 = _decs.sorted(by: by)
        self.resetItems(decs1)
   }
    
    fileprivate func resetItems(_ decs: [Declaration])
    {
        // popup menu item names must be unique but declarations may not be (e.g. for languages with overloading)
        // so we'll append some invisible spaces to the end of each name
        let c = Character(ZeroWidthSpaceChar)
        let decs2 = decs.mapi { (index, dec) -> Declaration in
            let suffix = String(repeating: String(c), count: index)
            return Declaration(name: dec.name + suffix, range: dec.range, isType: dec.isType)
        }

        self.removeAllItems()
        for dec in decs2
        {
            self.addItem(withTitle: dec.name)

            var attrs = [String: AnyObject]()
            attrs[NSFontAttributeName] = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize())
            if dec.isType
            {
                attrs[NSStrokeWidthAttributeName] = -4.0 as AnyObject?
            }
            
            let item = self.lastItem
            item!.attributedTitle = NSAttributedString(string: dec.name, attributes: attrs)
            item!.representedObject = dec.range
            item!.target = self
            item!.action = #selector(DeclarationsPopup.onSelectItem(_:))
        }
    }
    
    fileprivate struct Declaration
    {
        let name: String
        let range: NSRange
        let isType: Bool
    }
    
    fileprivate var _view: NSTextView?
    fileprivate var _decs: [Declaration]
}
