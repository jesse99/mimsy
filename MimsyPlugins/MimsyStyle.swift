import Cocoa

/// These are typically constructed from a setting and used to override existing
/// attribute styles (e.g. from a language file).
public enum MimsyStyle
{
    case backColor(NSColor)
    case color(NSColor)
    case skew(SkewArgument)
    case size(SizeArgument)
    case stroke(StrokeArgument)
    case underline(UnderLineArgument)
    case underlineColor(NSColor)
    
    public static func parse(_ app: MimsyApp, _ text: String) throws -> [MimsyStyle]
    {
        var styles: [MimsyStyle] = []
        
        let parts = text.components(separatedBy: " ")
        for part in parts
        {
            let fields = part.components(separatedBy: "=")
            if fields.count != 2
            {
                throw MimsyError("Expected key=value pair not '%@'", part)
            }
            
            switch fields[0]
            {
            case "back-color":      styles.append(.backColor(try parseColor(app, fields[1])))
            case "color":           styles.append(.color(try parseColor(app, fields[1])))
            case "skew":            styles.append(.skew(try SkewArgument.parse(fields[1])))
            case "size":            styles.append(.size(try SizeArgument.parse(fields[1])))
            case "stroke":          styles.append(.stroke(try StrokeArgument.parse(fields[1])))
            case "underline":       styles.append(.underline(try UnderLineArgument.parse(fields[1])))
            case "underline-color": styles.append(.underlineColor(try parseColor(app, fields[1])))
            default:                throw MimsyError("bad key: %@", fields[0])
            }
        }
        
        return styles
    }
    
    public static func apply(_ str: NSMutableAttributedString, _ styles: [MimsyStyle], _ range: NSRange)
    {
        for style in styles
        {
            switch style
            {
            case backColor(let color): str.addAttribute(NSAttributedString.Key.backgroundColor, value: color, range: range)
            case color(let color): str.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
            case skew(let arg): arg.apply(str, range)
            case size(let arg): arg.apply(str, range)
            case stroke(let arg): arg.apply(str, range)
            case underline(let arg): arg.apply(str, range)
            case underlineColor(let color): str.addAttribute(NSAttributedString.Key.underlineColor, value: color, range: range)
            }
        }
    }
    
    static func parseColor(_ app: MimsyApp, _ name: String) throws -> NSColor
    {
        if let color = app.mimsyColor(name)
        {
            return color
        }
        else
        {
            throw MimsyError("bad color name: '%@'", name)
        }
    }
}

public enum SkewArgument
{
    case italic
    case skewAmount(Float)
    
    static func parse(_ text: String) throws -> SkewArgument
    {
        switch text
        {
        case "italic":      return .italic
        case "0", "0.0":    return .skewAmount(0.0)
        default:
            let value = (text as NSString).floatValue
            if value != 0.0
            {
                return .skewAmount(value)
            }
            else
            {
                throw MimsyError("bad skew argument: '%@'", text)
            }
        }
    }

    func apply(_ str: NSMutableAttributedString, _ range: NSRange)
    {
        switch self
        {
        case .italic:
            str.addAttribute(NSAttributedString.Key.obliqueness, value: NSNumber(value: 0.15 as Float), range: range)
        case .skewAmount(let value):
            str.addAttribute(NSAttributedString.Key.obliqueness, value: NSNumber(value: value as Float), range: range)
        }
    }
}

public enum SizeArgument
{
    case muchSmaller
    case smaller
    case larger
    case muchLarger
    case pointSize(Float)
    
    static func parse(_ text: String) throws -> SizeArgument
    {
        switch text
        {
        case "much-smaller":    return .muchSmaller
        case "smaller":         return .smaller
        case "larger":          return .larger
        case "much-larger":     return .muchLarger
        case "0", "0.0":        return .pointSize(0.0)
        default:
            let value = (text as NSString).floatValue
            if value != 0.0
            {
                return .pointSize(value)
            }
            else
            {
                throw MimsyError("bad size argument: '%@'", text)
            }
        }
    }
    
    func apply(_ str: NSMutableAttributedString, _ range: NSRange)
    {
        var delta: Float = 0.0
        
        switch self
        {
        case .muchSmaller:           delta = -4.0
        case .smaller:               delta = -2.0
        case .larger:                delta = 2.0
        case .muchLarger:            delta = 4.0
        case .pointSize(let value):  delta = value
        }
        
        if let value = str.attribute(NSAttributedString.Key.font, at: range.location, effectiveRange: nil) as? NSFont
        {
            let size = max(Float(value.pointSize) + delta, 6.0)
            let font = NSFont(name: value.fontName, size: CGFloat(size))
            str.addAttribute(NSAttributedString.Key.font, value: font!, range: range)
        }
    }
}

public enum StrokeArgument
{
    case normal
    case outline
    case bold
    case veryBold
    case superBold
    case width(Float)
    
    static func parse(_ text: String) throws -> StrokeArgument
    {
        switch text
        {
        case "normal":      return .normal
        case "outline":     return .outline
        case "bold":        return .bold
        case "very-bold":   return .veryBold
        case "super-bold":  return .superBold
        case "0", "0.0":    return .width(0.0)
        default:
            let value = (text as NSString).floatValue
            if value != 0.0
            {
                return .width(value)
            }
            else
            {
                throw MimsyError("bad stroke argument: '%@'", text)
            }
        }
    }
    
    func apply(_ str: NSMutableAttributedString, _ range: NSRange)
    {
        var value: Float

        switch self
        {
        case .normal:        value = 0.0
        case .outline:       value = 3.0
        case .bold:          value = -3.0
        case .veryBold:      value = -5.0
        case .superBold:     value = -7.0
        case .width(let v):  value = v
        }

        str.addAttribute(NSAttributedString.Key.strokeWidth, value: NSNumber(value: value as Float), range: range)
}
}

public enum UnderLineArgument
{
    case none
    case single
    case thick
    case double
    case style(Int)
    
    static func parse(_ text: String) throws -> UnderLineArgument
    {
        switch (text)
        {
        case "none":    return .none
        case "single":  return .single
        case "thick":   return .thick
        case "double":  return .double
        case "0":       return .style(0)
        default:
            let value = (text as NSString).integerValue
            if value != 0
            {
                return .style(value)
            }
            else
            {
                throw MimsyError("bad underline argument: '%@'", text)
            }
        }
    }

    
    func apply(_ str: NSMutableAttributedString, _ range: NSRange)
    {
        var value: Int
        
        switch self
        {
        case .none:          value = NSUnderlineStyle().rawValue
        case .single:        value = NSUnderlineStyle.single.rawValue
        case .thick:         value = NSUnderlineStyle.thick.rawValue
        case .double:        value = NSUnderlineStyle.double.rawValue
        case .style(let v):  value = v
        }

        str.addAttribute(NSAttributedString.Key.underlineStyle, value: NSNumber(value: value as Int), range: range)
    }
}

