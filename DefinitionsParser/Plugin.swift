import Cocoa
import MimsyPlugins

class StdDefinitionsParser: MimsyPlugin, ItemParser
{
    override func onLoad(stage: Int) -> String?
    {
        if stage == 1
        {
            if let defs = definitionsPlugin
            {
                defs.register(self)
            }
        }
        
        return nil
    }
    
    var method: ParseMethod
    {
        get {return .Regex}
    }
    
    // Threaded code
    func tryParse(path: MimsyPath) throws -> [ItemName]?
    {
        var items: [ItemName]? = nil
        
        if let lang = app.findLanguage(path)    // TODO: this may not be quite thread safe
        {
            let patterns = lang.getPatterns("Function") + lang.getPatterns("Structure")
            if !patterns.isEmpty
            {
                let re = try findRegex(patterns)
                items = try parse(lang, re, path)
            }
        }
        
        return items
    }
    
    // Threaded code
    func findRegex(var patterns: [String]) throws -> NSRegularExpression
    {
        patterns = patterns.map {"(?:" + $0 + ")"}
        let pattern = patterns.joinWithSeparator("|")
        
        if let re = regexen[pattern]
        {
            return re
        }
        else
        {
            let re = try NSRegularExpression(pattern: pattern, options: [.AllowCommentsAndWhitespace, .AnchorsMatchLines])
            regexen[pattern] = re
            return re
        }
    }
    
    // Threaded code
    func parse(lang: MimsyLanguage, _ re: NSRegularExpression, _ path: MimsyPath) throws -> [ItemName]
    {
        var items: [ItemName] = []
//        app.log("Plugins", "parsing %@", path.lastComponent())
        
        let contents = try NSString(contentsOfFile: path.asString(), encoding: NSUTF8StringEncoding)
        re.enumerateMatchesInString(contents as String, options: NSMatchingOptions(rawValue: 0), range: NSRange(location: 0, length: contents.length))
        { (match, flags, stop) in
            if let match = match
            {
                for i in 1..<match.numberOfRanges
                {
                    let range = match.rangeAtIndex(i)
                    if range.length > 0
                    {
                        let name = contents.substringWithRange(range)
                        if self.isDeclaration(lang, contents, range)
                        {
                            items.append(ItemName.Declaration(name: name, location: range.location))
//                            self.app.log("Plugins", "   found %@ declaration", name)
                        }
                        else
                        {
                            items.append(ItemName.Definition(name: name, location: range.location))
//                            self.app.log("Plugins", "   found %@ definition", name)
                        }
                        break
                    }
                }
            }
        }
        
        return items
    }
    
    func isDeclaration(lang: MimsyLanguage, _ text: NSString, _ range: NSRange) -> Bool
    {
        if lang.name == "c" || lang.name == "c++"
        {
            var i = range.location + range.length
            while i < min(text.length, range.location + range.length + 200)
            {
                let ch = Character(UnicodeScalar(text.characterAtIndex(i)))
                if ch == "{"
                {
                    return false
                }
                else if ch == ";"
                {
                    return true
                }
                i += 1
            }
        }
        
        return false
    }
    
    var regexen: [String: NSRegularExpression] = [:]
}
