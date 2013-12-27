#import "OpenSelection.h"

#import "Assert.h"
#import "DirectoryController.h"
#import "Logger.h"
#import "OpenFile.h"
#import "ScannerCategory.h"
#import "StringCategory.h"
#import "TranscriptController.h"
#import "Utils.h"

typedef bool (*ValidIndexCallback)(NSString* text, NSUInteger index);

static bool _validHtml(NSString* text, NSUInteger index)
{
	if (index < text.length)
	{
		unichar ch = [text characterAtIndex:index];
		if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'))
			return true;
		
		static NSCharacterSet* chars = nil;
		if (!chars)
			chars = [NSCharacterSet characterSetWithCharactersInString:@":?#/+-.@%_~!$&'()*,;="];	// see <http://tools.ietf.org/html/rfc3986#appendix-A>
		return [chars characterIsMember:ch];		// note that we don't allow [] because they are used in wiki formatting
	}
	
	return false;
}

static bool _validFile(NSString* text, NSUInteger index)
{
	if (index < text.length)
	{
		static NSCharacterSet* chars = nil;
		if (!chars)
			chars = [NSCharacterSet characterSetWithCharactersInString:@"\n\r\t <>:'\"("];

		unichar ch = [text characterAtIndex:index];
		return ![chars characterIsMember:ch];
	}
	
	return false;
}

static void _extendSelection(ValidIndexCallback predicate, NSString* text, NSUInteger* location, NSUInteger* length)
{
	while (predicate(text, *location - 1))
	{
		--(*location);
		++(*length);
	}
	
	while (predicate(text, *location + *length))
		++(*length);
}

static bool _doAbsolutePath(NSString* path, int line, int col)
{
	bool opened = false;
	
	if ([path isAbsolutePath])
	{
		BOOL isDir = FALSE;
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && !isDir)
		{
			opened = [OpenFile openPath:path atLine:line atCol:col withTabWidth:1];
		}
		else if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath:path])
		{
			opened = [OpenFile openPath:path atLine:line atCol:col withTabWidth:1];
		}
	}
	
	return opened;
}

// If the name is an absolute path then we can open it with Mimsy if it's
// a file type we handle or launch it with an external app if not.
static bool _openAbsolutePath(NSString* path, int line, int col)
{
	bool opened = false;
	
	if (_doAbsolutePath(path, line, col))
	{
		LOG_DEBUG("Text", "opened using absolute path");
		opened = true;
	}
	
	return opened;
}

static bool _openRelativePath(NSString* path, int line, int col)
{
	__block bool opened = false;
	
	if (![path isAbsolutePath])
	{
		DirectoryController* controller = [DirectoryController getCurrentController];
		if (controller)
		 {
			 NSString* candidate = [NSString pathWithComponents:@[controller.path, path]];
			 if (_doAbsolutePath(candidate, line, col))
			 {
				 LOG_DEBUG("Text", "opened using relative path");
				 opened = true;
			 }
		 }
	}
	
	return opened;
}

// We assume that if we can find a match under the current directory that is what the user
// wants to open. (And we do a slow manual search because the locate command isn't always
// available, and even when it is, it does not match the current file system state).
static bool _openLocalPath(NSString* path, int line, int col)
{
	__block bool opened = false;
	
	if (![path isAbsolutePath] && path.length > 2)		// don't do something lame like open all files with "e"
	{
		DirectoryController* controller = [DirectoryController getCurrentController];
		if (controller)
		{
			[Utils enumerateDeepDir:controller.path glob:nil error:NULL block:^(NSString* item)
			{
				NSRange range = [item rangeOfString:path];
				if (range.location != NSNotFound)
					if (_doAbsolutePath(item, line, col))
					{
						LOG_DEBUG("Text", "opened using local path");
						opened = true;
					}
			}];
		}
	}
	
	return opened;
}

// TODO: The operation of open selection is a little weird: when searching for
// local files we use the full file name, but when using the locate command
// we allow partial file name matches.
static NSArray* _locateFiles(NSString* path)
{
	NSArray* components = [path pathComponents];
	NSString* fileName = [components lastObject];
	NSString* file = [@"/" stringByAppendingString:fileName];
	
	NSTask* task = [NSTask new];	
	[task setLaunchPath:@"/usr/bin/locate"];				// TODO: may want to put this (and the arguments) into some sort of app settings file
	[task setArguments:@[@"-i", @"-l", @"100", file]];
	[task setStandardOutput:[NSPipe new]];
	[task setStandardError:[NSPipe new]];
	
	NSArray* files = @[];
	NSString* stdout = nil;
	NSString* stderr = nil;
	int returncode = [Utils run:task stdout:&stdout stderr:&stderr];
	
	if (returncode == 0)
	{
		files = [stdout splitByString:@"\n"];
	}
	else
	{
		stderr = [stderr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		[TranscriptController writeStderr:@"Error running the locate command: "];
		[TranscriptController writeStderr:stderr];
		[TranscriptController writeStderr:@"\n"];
	}
	
	return files;
}

// TODO:
// add support for preferred paths
//    preferred are:
//       current directory
//       list of directories in settings file
// may want non-preferred
//    e.g. any directory starting with a dot
// if there are four total or four preferred then
//    open them
// else
//    pop up a picker dialog
static bool _openLocatedFiles(NSArray* candidates, int line, int col)
{
	bool opened = false;
	
	if (candidates.count < 20)
	{
		for (NSString* path in candidates)
		{
			if (_doAbsolutePath(path, line, col))
			{
				LOG_DEBUG("Text", "opened using located path");
				opened = true;
			}
		}
	}
	
	//			NSString* name = [path lastPathComponent];
	
	//			Boss boss = ObjectModel.Create("FileSystem");
	//			var fs = boss.Get<IFileSystem>();
	//			var candidates = new List<string>(fs.LocatePath("/" + name));
	
	// This isn't as tight a test as we would like, but I don't think we can
	// do much better because of links. For example, <AppKit/NSResponder.h>
	// maps to a path like:
	//  "/System/Library/Frameworks/AppKit.framework/Versions/C/Headers/NSResponder.h".
	//			candidates.RemoveAll(c => System.IO.Path.GetFileName(path) != name);
	
	//			if (candidates.Count > 0)
	//				found = _openLocalPath(candidates.ToArray(), name, line, col) || DoOpenGlobalPath(candidates.ToArray(), name, line, col);
	//			else
	if (!opened)
		LOG_DEBUG("Text", "open using locate failed (no candidates)");
	
	return opened;
}

static void _getLineAndCol(NSString* text, NSUInteger location, NSUInteger length, int* line, int* col)
{
	int l = -1, c = -1;
	
	// gmcs - Application.cs(14,10)
	NSScanner* scanner = [NSScanner scannerWithString:text];
	[scanner setScanLocation:location + length];
	
	if ([scanner skip:'('] && [scanner scanInt:&l] && [scanner skip:','] && [scanner scanInt:&c] && [scanner skip:')'])
	{
		*line = l;
		*col = c;
	}
	
	// make - Makefile:28
	[scanner setScanLocation:location + length];
	if ([scanner skip:':'] && [scanner scanInt:&l])
	{
		*line = l;
	}
	
	// gendarme - Application.cs(~10)
	[scanner setScanLocation:location + length];
	if ([scanner skip:'('] && [scanner skip:0x2248] && [scanner scanInt:&l] && [scanner skip:')'])
	{
		*line = l;
	}
	
	// gendarme - Application.cs(?10)		TODO: not sure why we get this sometimes from gendarme...
	[scanner setScanLocation:location + length];
	if ([scanner skip:'('] && [scanner skip:'?'] && [scanner scanInt:&l] && [scanner skip:')'])
	{
		*line = l;
	}
}

static bool _openFile(NSString* text, NSUInteger location, NSUInteger length)
{
	NSString* path = [text substringWithRange:NSMakeRange(location, length)];
	LOG_DEBUG("Text", "trying path '%s'", path.UTF8String);
	
	int line = -1, col = -1;
	_getLineAndCol(text, location, length, &line, &col);
	bool found = false;
	
	// We don't want to try paths like "//code.google.com/p/mobjc/w/list" because
	// we'll find "/Developer/SDKs/MacOSX10.5.sdk/usr/include/c++/4.0.0/list".
	if (![path startsWith:@"//"])
	{
		if (!found)
			found = _openAbsolutePath(path, line, col);
		
		if (!found)
			found = _openRelativePath(path, line, col);
		
		if (!found)
			found = _openLocalPath(path, line, col);
		
		if (!found)
		{
			NSArray* candidates = _locateFiles(path);
			found = _openLocatedFiles(candidates, line, col);
		}
	}
	
	return found;
}

static bool _openHtml(NSString* text, NSUInteger location, NSUInteger length)
{
	NSString* path = [text substringWithRange:NSMakeRange(location, length)];
	LOG_DEBUG("Text", "trying URL '%s'", path.UTF8String);
	
	bool found = false;
		
	return found;
}

// Here are some test cases which should work:
// source/plugins/find/Find.cs							relative path (this should work as well for files not in the locate db)
// DatabaseTest.cs										local file
// <AppKit/NSResponder.h>								non-local relative path
// /Users/jessejones/Source/Continuum/source/plugins/find/AssemblyInfo.cs		absolute path
// http://dev.mysql.com/tech-resources/articles/why-data-modeling.html			url
// http://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/OSX_Technology_Overview/About/About.html relative url
// NSWindow.h											file in preferred directory
// c#.cs												file not in preferred directory
bool openTextRange(NSTextStorage* storage, NSRange range)
{
	bool opened = false;
	LOG_INFO("Text", "trying to open a selection");
	
	NSString* text = [storage string];
	if (!opened)
	{
		NSUInteger loc = range.location;
		NSUInteger len = range.length;
		_extendSelection(_validFile, text, &loc, &len);
		opened = _openFile(text, loc, len);
	}
	
	if (!opened)
	{
		NSUInteger loc = range.location;
		NSUInteger len = range.length;
		_extendSelection(_validHtml, text, &loc, &len);
		opened = _openHtml(text, loc, len);
	}
	
	return opened;
}