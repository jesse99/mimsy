import Foundation

// Would be simpler to use class members but class fields are not supported in
// XCode 6.1.
var _instance: BuildErrors = BuildErrors()

/// Used to parse and display build errors.  
open class BuildErrors : NSObject
{    
    class var instance: BuildErrors {return _instance}
    
    func appSettingsChanged()
    {
        _patterns = [Pattern]()
        let app = NSApplication.shared().delegate as! AppDelegate;
        app.layeredSettings().enumerate("BuildError", with: self.parseSetting)
        
        // We want to use the regexen that are able to pick out more information
        // first because the regexen can match the same messages.
        _patterns = _patterns.sorted {$0.fields.count > $1.fields.count}
    }
    
    func parseErrors(_ text: NSString, range: NSRange)
    {
        _errors = [Error]()
        _index = -1
        
        var matches = [Int: Bool]()
        
        let remap = getRemapPath()
        for pattern in _patterns
        {
            pattern.regex.enumerateMatches(in: text as String, options: [], range: range, using:
            {
            (match, flags, stop) in
                if match != nil && matches[match!.range.location] == nil
                {
                    let error = Error(text: text, pattern: pattern, match: match!, remap: remap)
                    matches[match!.range.location] = true
                    self._errors.append(error)
                    //SLOG("App", "found error at \(match!.range.location):\(match!.range.length): \(text.substringWithRange(match!.range))")
                }
            })
        }

        _errors = _errors.sorted {$0.transcriptRange.range.location < $1.transcriptRange.range.location}
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
        showErrorInFile()
    }
    
    func gotoPreviousError()
    {
        gotoNewError(-1)
        showErrorInFile()
    }
    
    fileprivate func getRemapPath() -> [String]
    {
        var mapping = ["", ""]
        
        if let context = activeContext, let settings = context.layeredSettings()
        {
            let remap = settings.stringValue("RemapBuildPath", missing: ":")
            let parts = remap.components(separatedBy: ":")
            if parts.count == 2
            {
                mapping = parts
            }
            else
            {
                TranscriptController.writeError("RemapBuildPath should be formatted as '<old path>:<new path>' not '\(remap)'")
            }
        }
        
        return mapping
    }
    
    fileprivate func gotoNewError(_ delta: Int)
    {
        let view = TranscriptController.getView()
        if _index >= 0 && _index < _errors.count
        {
            let oldError = _errors[_index]
            let range = oldError.transcriptRange.range
            if range.location != NSNotFound
            {
                view?.textStorage!.removeAttribute(NSUnderlineStyleAttributeName, range: range)
            }
        }
        
        _index += delta
        let error = _errors[_index]
        let range = error.transcriptRange.range
        //SLOG("App", "goto error at \(range.location):\(range.length): \(error.message)")
        if range.location != NSNotFound
        {
            let attrs = [NSUnderlineStyleAttributeName: NSNumber(value: NSUnderlineStyle.styleSingle.rawValue as Int)]
            view?.textStorage!.addAttributes(attrs, range: range)

            // Typically we'd call showFindIndicatorForRange but that seems a bit
            // distracting when multiple windows are involved.
            let delay = DispatchTime.now() + Double(Int64(10*NSEC_PER_MSEC)) / Double(NSEC_PER_SEC)
            let main = DispatchQueue.main
            main.asyncAfter(deadline: delay, execute: {view?.scrollRangeToVisible(range)})
        }
    }
    
    fileprivate func showErrorInFile()
    {
        let error = _errors[_index]
        if error.path != nil && error.fileRange != nil  // this code would be simpler by matching on a tuple but that doesn't work with Xcode 6.1
        {
            let range = error.fileRange!.range.location != NSNotFound ? error.fileRange!.range : NSMakeRange(0, 0)  // NSNotFound means that the range was deleted
            if let controller = error.fileRange!.controller
            {
                controller.getTextView().setSelectedRange(range)
                controller.getTextView().scrollRangeToVisible(range)
            }
            else
            {
                OpenFile.open(error.path!, with: range)
            }
        }
        else if error.path != nil
        {
            let main = DispatchQueue.main
            let delay = DispatchTime.now() + Double(Int64(200*NSEC_PER_MSEC)) / Double(NSEC_PER_SEC)
            main.asyncAfter(deadline: delay,
            execute: { () in
                OpenFile.open(error.path!, atLine: error.line, atCol: error.column, withTabWidth: 1, completed:
                    { (tc) -> Void in
                        // We need to defer this because the selection isn't correct when the document is opened.
                        if let r = tc?.getTextView().selectedRange
                        {
                            error.fileRange = PersistentRange(error.path!, range: r, block: nil)
                        }
                })
            })
        }
        else
        {
            // No path so we can't show the error in context.
        }
    }
    
    fileprivate func parseSetting(_ fileName: String!, value: String!)
    {
        func parseTags(_ tags: String) -> [Character: Int]
        {
            var result = [Character: Int]()
            
            var index = 1
            for char in tags.characters
            {
                switch char
                {
                case "F", "L", "C", "M":
                    result[char] = index
                    index += 1
                default:
                    TranscriptController.writeError("BuildError in \(fileName) tags should contain FLCM characters, not '\(tags)'")
               }
            }
            
            return result
        }
        
        func createRegex(_ pattern: String) -> NSRegularExpression?
        {
            do {
                return try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.anchorsMatchLines)
            } catch let error as NSError {
                TranscriptController.writeError("BuildError in \(fileName) regex '\(pattern)' is malformed: \(error.localizedFailureReason)")
                return nil
            } catch {
                TranscriptController.writeError("BuildError in \(fileName) regex '\(pattern)' is malformed: unknown error")
                return nil
            }
        }
        
        // BuildError: FLCM ^([^:\r\n]+):(\d+):(\d+):\s+\w+:\s+(.+)$
        let range = value.range(of: " ")
        if let range = range
        {
            let tags = parseTags(value.substring(to: range.lowerBound))
            let regex = createRegex(value.substring(from: range.lowerBound))
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

    fileprivate class Error
    {
        init(text: NSString, pattern: Pattern, match: NSTextCheckingResult, remap: [String])
        {
            var file: MimsyPath?
            switch pattern.fields["F"]
            {
            case .some(let i):
                var s = text.substring(with: match.rangeAt(i))
                if !remap.isEmpty && !remap[0].isEmpty
                {
                    s = s.replacingOccurrences(of: remap[0], with: remap[1])
                }
                file = MimsyPath(withString: s)
            default:
                file = nil
            }
            
            if let i = pattern.fields["L"]
            {
                line = Int(text.substring(with: match.rangeAt(i)))!
            }
            else
            {
                line = -1
            }
            
            if let i = pattern.fields["C"]
            {
                column = Int(text.substring(with: match.rangeAt(i)))!
            }
            else
            {
                column = -1
            }
            
            switch pattern.fields["M"]
            {
            case .some(let i):
                message = text.substring(with: match.rangeAt(i))
                transcriptRange = PersistentRange(TranscriptController.getInstance(), range: match.rangeAt(i))
            default:
                message = nil
                transcriptRange = PersistentRange(TranscriptController.getInstance(), range: match.range)
            }

            let current = DirectoryController.getCurrent()
            if current != nil && file != nil
            {
                if let paths = OpenFile.resolve(file!, rootedAt: current!.path), paths.count > 0
                {
                    // Hopefully tools will provide more than just a file name on errors.
                    // Failing that people will hopefully not reuse source file names.
                    path = paths[0]
                }
                else
                {
                    path = nil;
                }
            }
            else
            {
            
                path = nil
            }
        }
        
        let transcriptRange: PersistentRange
        var fileRange: PersistentRange? = nil
        
        let path: MimsyPath?
        let line: Int
        let column: Int
        let message: String?
    }
    
    fileprivate struct Pattern
    {
        let fields: [Character: Int]
        let regex: NSRegularExpression
    }
    
    fileprivate var _patterns = [Pattern]()
    fileprivate var _errors = [Error]()
    fileprivate var _index: Int = -1
}
