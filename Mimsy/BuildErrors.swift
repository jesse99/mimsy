import Foundation

// Would be simpler to use class members but class fields are not supported in
// XCode 6.1.
var _instance: BuildErrors = BuildErrors()

// Used to parse and display build errors.
@objc class BuildErrors
{    
    class var instance: BuildErrors {return _instance}
    
    func appSettingsChanged()
    {
        _patterns = [Pattern]()
        AppSettings.enumerate("BuildError", with: self.parseSetting)
        
        // We want to use the regexen that are able to pick out more information
        // first because the regexen can match the same messages.
        _patterns = sorted(_patterns) {$0.fields.count > $1.fields.count}
    }
    
    func parseErrors(text: NSString, range: NSRange)
    {
        _errors = [Error]()
        _index = -1
        
        var matches = [Int: Bool]()

        for pattern in _patterns
        {
            pattern.regex.enumerateMatchesInString(text, options: nil, range: range, usingBlock:
            {
            (match, flags, stop) -> Void in
                if matches[match.range.location] == nil
                {
                    let error = Error(text: text, pattern: pattern, match: match)
                    matches[match.range.location] = true
                    self._errors.append(error)
                }
            })
        }

        _errors = sorted(_errors) {$0.transcriptRange.location < $1.transcriptRange.location}
    }
    
    func canGotoNextError() -> Bool
    {
        return _index + 1 < _errors.count
    }
    
    func canGotoPreviousError() -> Bool
    {
        return _index > 0
    }
    
    func gotoNextError()
    {
        gotoNewError(1)
    }
    
    func gotoPreviousError()
    {
        gotoNewError(-1)
    }
    
    private func gotoNewError(delta: Int)
    {
        let view = TranscriptController.getView()
        if _index >= 0 && _index < _errors.count
        {
            let oldError = _errors[_index]
            view.textStorage!.removeAttribute(NSUnderlineStyleAttributeName, range: oldError.transcriptRange)
        }
        
        _index += delta
        let error = _errors[_index]
        
        let attrs = [NSUnderlineStyleAttributeName: NSUnderlineStyleSingle]
        view.textStorage!.addAttributes(attrs, range: error.transcriptRange)

        // Typically we'd call showFindIndicatorForRange but that seems a bit
        // distracting when multiple windows are involved.
        view.scrollRangeToVisible(error.transcriptRange)
      
        if let file = error.file
        {
            openFile(file, error.line, error.column)
        }
    }
    
    private func parseSetting(fileName: String!, value: String!)
    {
        func parseTags(tags: String) -> [Character: Int]
        {
            var result = [Character: Int]()
            
            var index = 1
            for char in tags
            {
                switch char
                {
                case "F", "L", "C", "M":
                    result[char] = index++
                default:
                    TranscriptController.writeError("BuildError in \(fileName) tags should contain FLCM characters, not '\(tags)'")
               }
            }
            
            return result
        }
        
        func createRegex(pattern: String) -> NSRegularExpression?
        {
            var error: NSError?
            let regex = NSRegularExpression(pattern: pattern, options: NSRegularExpressionOptions.AnchorsMatchLines, error: &error)
            if let error = error
            {
                TranscriptController.writeError("BuildError in \(fileName) regex '\(pattern)' is malformed: \(error.localizedFailureReason)")
                return nil
            }
            return regex
        }
        
        // BuildError: FLCM ^([^:\r\n]+):(\d+):(\d+):\s+\w+:\s+(.+)$
        let range = value.rangeOfString(" ")
        if let range = range
        {
            let tags = parseTags(value.substringToIndex(range.startIndex))
            let regex = createRegex(value.substringFromIndex(range.startIndex.successor()))
            if tags.count > 0 && regex != nil
            {
                let element = Pattern(fields: tags, regex: regex!)
                _patterns.append(element)
                
            }
        }
        else
        {
            TranscriptController.writeError("BuildError in \(fileName) should have tags then a space then a regex pattern, not '\(value)'")
        }
    }

    private class Error
    {
        init(text: NSString, pattern: Pattern, match: NSTextCheckingResult)
        {
            transcriptRange = match.range
            fileRange = NSMakeRange(NSNotFound, 0)
            path = ""
            
            switch pattern.fields["F"]
            {
            case .Some(let i): file = text.substringWithRange(match.rangeAtIndex(i))
            default: file = nil
            }
            
            if let i = pattern.fields["L"]
            {
                line = Int32(text.substringWithRange(match.rangeAtIndex(i)).toInt()!)
            }
            
            if let i = pattern.fields["C"]
            {
                column = Int32(text.substringWithRange(match.rangeAtIndex(i)).toInt()!)
            }
            
            switch pattern.fields["M"]
            {
            case .Some(let i): message = text.substringWithRange(match.rangeAtIndex(i))
            default: message = nil
            }
        }
        
        let transcriptRange: NSRange
        var fileRange: NSRange
        var path: String            // TODO: remove this once we switch to PersistentRange
        
        let file: String?
        let line: Int32 = -1
        let column: Int32 = -1
        let message: String?
    }
    
    private struct Pattern
    {
        let fields: [Character: Int]
        let regex: NSRegularExpression
    }
    
    private var _patterns = [Pattern]()
    private var _errors = [Error]()
    private var _index: Int = -1
}
