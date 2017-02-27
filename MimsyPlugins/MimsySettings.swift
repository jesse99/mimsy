import Foundation

/// Used to access Mimsy and plugin preferences.
@objc public protocol MimsySettings
{
    /// Returns either the named value or missing.
    func boolValue(_ name: String, missing: Bool) -> Bool

    /// Returns either the named value or missing.
    func intValue(_ name: String, missing: Int) -> Int
    
    /// Returns either the named value or missing.
    func floatValue(_ name: String, missing: Float) -> Float

    /// Returns either the named value or missing.
    func stringValue(_ name: String, missing: String) -> String
    
    /// Returns all values using the name.
    func stringValues(_ name: String) -> [String]
}
