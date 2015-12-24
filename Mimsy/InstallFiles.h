#import <Foundation/Foundation.h>
#import "MimsyPlugins.h"

/// Installs files from the Resources directory in the app bundle to ~/Library/Application\ Support/Mimsy.
/// This is done to allow the user to customize Mimsy's behavior and, in so far as possible, to allow
/// those changes to persist when Mimsy is upgraded.
@interface InstallFiles : NSObject

/// The path to install files to. Typically ~/Library/Application\ Support/Mimsy. This directory will be
/// created if it does not exist.
- (id)initWithDstPath:(MimsyPath*)path;

/// Files or directories in the Resources directory of the bundle which should be be installed. Note
/// that directories are recursively copied.
- (void)addSourceFile:(NSString*)item;

/// Like addSourceFile except that it takes a full path. Returns a path relative to the install directory.
- (void)addSourcePath:(MimsyPath*)path;

/// Updates the installed files (trying to be smart about not over-writing user changes).
- (void)install;

@end
