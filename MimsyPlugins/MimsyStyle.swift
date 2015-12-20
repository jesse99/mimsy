import Cocoa

/// These are typically constructed from a setting and used to override existing
/// attribute styles (e.g. from a language file).
public enum MimsyStyle
{
    case BackColor(NSColor)
    case Color(NSColor)
    case Skew(SkewArgument)
    case Size(SizeArgument)
    case Stroke(StrokeArgument)
    case Underline(UnderLineArgument)
    case UnderlineColor(NSColor)
    
    public static func parse(app: MimsyApp, _ text: String) throws -> [MimsyStyle]
    {
        var styles: [MimsyStyle] = []
        
        let parts = text.componentsSeparatedByString(" ")
        for part in parts
        {
            let fields = part.componentsSeparatedByString("=")
            if fields.count != 2
            {
                throw MimsyError("Expected key=value pair not '%@'", part)
            }
            
            switch fields[0]
            {
            case "back-color":      styles.append(.BackColor(try parseColor(app, fields[1])))
            case "color":           styles.append(.Color(try parseColor(app, fields[1])))
            case "skew":            styles.append(.Skew(try SkewArgument.parse(fields[1])))
            case "size":            styles.append(.Size(try SizeArgument.parse(fields[1])))
            case "stroke":          styles.append(.Stroke(try StrokeArgument.parse(fields[1])))
            case "underline":       styles.append(.Underline(try UnderLineArgument.parse(fields[1])))
            case "underline-color": styles.append(.UnderlineColor(try parseColor(app, fields[1])))
            default:                throw MimsyError("bad key: %@", fields[0])
            }
        }
        
        return styles
    }
    
    public static func apply(str: NSMutableAttributedString, _ styles: [MimsyStyle], _ range: NSRange)
    {
        for style in styles
        {
            switch style
            {
            case BackColor(let color): str.addAttribute(NSBackgroundColorAttributeName, value: color, range: range)
            case Color(let color): str.addAttribute(NSForegroundColorAttributeName, value: color, range: range)
            case Skew(let arg): arg.apply(str, range)
            case Size(let arg): arg.apply(str, range)
            case Stroke(let arg): arg.apply(str, range)
            case Underline(let arg): arg.apply(str, range)
            case UnderlineColor(let color): str.addAttribute(NSUnderlineColorAttributeName, value: color, range: range)
            }
        }
    }
    
    static func parseColor(app: MimsyApp, _ name: String) throws -> NSColor
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
    case Italic
    case SkewAmount(Float)
    
    static func parse(text: String) throws -> SkewArgument
    {
        switch text
        {
        case "italic":      return .Italic
        case "0", "0.0":    return .SkewAmount(0.0)
        default:
            let value = (text as NSString).floatValue
            if value != 0.0
            {
                return .SkewAmount(value)
            }
            else
            {
                throw MimsyError("bad skew argument: '%@'", text)
            }
        }
    }

    func apply(str: NSMutableAttributedString, _ range: NSRange)
    {
        switch self
        {
        case Italic:
            str.addAttribute(NSObliquenessAttributeName, value: NSNumber(float: 0.15), range: range)
        case SkewAmount(let value):
            str.addAttribute(NSObliquenessAttributeName, value: NSNumber(float: value), range: range)
        }
    }
}

public enum SizeArgument
{
    case MuchSmaller
    case Smaller
    case Larger
    case MuchLarger
    case PointSize(Float)
    
    static func parse(text: String) throws -> SizeArgument
    {
        switch text
        {
        case "much-smaller":    return .MuchSmaller
        case "smaller":         return .Smaller
        case "larger":          return .Larger
        case "much-larger":     return .MuchLarger
        case "0", "0.0":        return .PointSize(0.0)
        default:
            let value = (text as NSString).floatValue
            if value != 0.0
            {
                return .PointSize(value)
            }
            else
            {
                throw MimsyError("bad size argument: '%@'", text)
            }
        }
    }
    
    func apply(str: NSMutableAttributedString, _ range: NSRange)
    {
        var delta: Float = 0.0
        
        switch self
        {
        case MuchSmaller:           delta = -4.0
        case Smaller:               delta = -2.0
        case Larger:                delta = 2.0
        case MuchLarger:            delta = 4.0
        case PointSize(let value):  delta = value
        }
        
        let effRange = UnsafeMutablePointer<NSRange>(nil)
        if let value = str.attribute(NSFontAttributeName, atIndex: range.location, effectiveRange: effRange) as? NSFont
        {
            let size = max(Float(value.pointSize) + delta, 6.0)
            let font = NSFont(name: value.fontName, size: CGFloat(size))
            str.addAttribute(NSFontAttributeName, value: font!, range: range)
        }
    }
}

public enum StrokeArgument
{
    case Normal
    case Outline
    case Bold
    case VeryBold
    case SuperBold
    case Width(Float)
    
    static func parse(text: String) throws -> StrokeArgument
    {
        switch text
        {
        case "normal":      return .Normal
        case "outline":     return .Outline
        case "bold":        return .Bold
        case "very-bold":   return .VeryBold
        case "super-bold":  return .SuperBold
        case "0", "0.0":    return .Width(0.0)
        default:
            let value = (text as NSString).floatValue
            if value != 0.0
            {
                return .Width(value)
            }
            else
            {
                throw MimsyError("bad stroke argument: '%@'", text)
            }
        }
    }
    
    func apply(str: NSMutableAttributedString, _ range: NSRange)
    {
        var value: Float

        switch self
        {
        case Normal:        value = 0.0
        case Outline:       value = 3.0
        case Bold:          value = -3.0
        case VeryBold:      value = -5.0
        case SuperBold:     value = -7.0
        case Width(let v):  value = v
        }

        str.addAttribute(NSStrokeWidthAttributeName, value: NSNumber(float: value), range: range)
}
}

public enum UnderLineArgument
{
    case None
    case Single
    case Thick
    case Double
    case Style(Int)
    
    static func parse(text: String) throws -> UnderLineArgument
    {
        switch (text)
        {
        case "none":    return .None
        case "single":  return .Single
        case "thick":   return .Thick
        case "double":  return .Double
        case "0":       return .Style(0)
        default:
            let value = (text as NSString).integerValue
            if value != 0
            {
                return .Style(value)
            }
            else
            {
                throw MimsyError("bad underline argument: '%@'", text)
            }
        }
    }

    
    func apply(str: NSMutableAttributedString, _ range: NSRange)
    {
        var value: Int
        
        switch self
        {
        case None:          value = NSUnderlineStyle.StyleNone.rawValue
        case Single:        value = NSUnderlineStyle.StyleSingle.rawValue
        case Thick:         value = NSUnderlineStyle.StyleThick.rawValue
        case Double:        value = NSUnderlineStyle.StyleDouble.rawValue
        case Style(let v):  value = v
        }

        str.addAttribute(NSUnderlineStyleAttributeName, value: NSNumber(integer: value), range: range)
    }
}

