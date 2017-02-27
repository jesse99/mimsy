import Foundation

/// Used to match file names using a small regex sort of language:
/// * \* matches zero or more characters
/// * ? matches a single character
/// * [x] matches the characters between the brackets
/// * everything else matches itself
@objc public protocol MimsyGlob
{
    /// Returns true if at least one glob matches text.
    func matches(_ path: MimsyPath) -> Bool
}
