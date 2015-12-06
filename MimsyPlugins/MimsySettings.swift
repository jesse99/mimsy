import Foundation

/// Used to access Mimsy and plugin preferences.
@objc public protocol MimsySettings
{
    /// Returns either the named value or missing.
    func boolValue(name: String, missing: Bool) -> Bool

    /// Returns either the named value or missing.
    func intValue(name: String, missing: Int) -> Int

    /// Returns either the named value or missing.
    func stringValue(name: String, missing: String) -> String
    
    /// Returns all values using the name.
    func stringValues(name: String) -> [String]
}
