import Foundation

/// Represents a directory that the user has opened.
@objc public protocol MimsyProject
{
    /// Full path to the project's directory.
    var path: MimsyPath {get}
    
    /// Contains settings for the project and the app, but not for the current
    /// plugin or languages.
    var settings: MimsySettings {get}

    /// Returns a list of full paths within the project that match name which
    /// may be either a file name or a (usually relative) path.
    func resolve(_ name: String) -> [MimsyPath]
}
