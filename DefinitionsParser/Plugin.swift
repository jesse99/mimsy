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
        else if (stage == 2)
        {
            findLanguages()
        }
        
        return nil
    }
    
    func findLanguages()
    {
        // Note that we assume that Globs and the existence of Function/Structure change very
        // rarely so we don't bother rebuilding this info when the user edits settings. (We
        // could of course because doing this isn't that expensive but settings can change
        // every time the user switches between different projects which could happen quite
        // a bit, we'd have to make this thread safe).
        for lang in app.languages()
        {
            if !lang.getPatterns("Function").isEmpty || !lang.getPatterns("Structure").isEmpty
            {
                let globs = lang.settings.stringValue("Globs", missing: "")
                let patterns = globs.componentsSeparatedByString(" ")
                for pattern in patterns
                {
                    if pattern.hasPrefix("*.")
                    {
                        let name = pattern.substringFromIndex(pattern.startIndex.advancedBy(2))
                        languages[name] = lang
                    }
                }
            }
        }
    }
    
    var method: ParseMethod
    {
        get {return .Regex}
    }
    
    var extensionNames: [String]
    {
        get {return Array(languages.keys)}
    }
    
    // Threaded code
    func parse(path: MimsyPath) throws -> [ItemName]
    {
        var items: [ItemName]
        
        let lang = languages[path.extensionName()!]!  // we should only have been called if the file's extension matches one in keys so the bangs are OK
        
        let patterns = lang.getPatterns("Function") + lang.getPatterns("Structure") // TODO: not thread safe?
        if !patterns.isEmpty                          // could be empty if the user has edited the language file
        {
            let re = try findRegex(patterns)
            items = try parse(lang, re, path)
        }
        else
        {
            items = []
        }
        
        return items
    }
    
    // Threaded code
    func findRegex(var patterns: [String]) throws -> NSRegularExpression
    {
        // It's easier to cache patterns instead of directly caching regexen because
        // that way we don't have to detect edits to language files.
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
    
    var regexen: [String: NSRegularExpression] = [:]    // key is a regex pattern
    var languages: [String: MimsyLanguage] = [:]        // key is a file extension
}
