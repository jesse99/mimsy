#import "OpenSelection.h"

#import "AppDelegate.h"
#import "DirectoryController.h"
#import "Glob.h"
#import "OpenFile.h"
#import "ScannerCategory.h"
#import "SelectNameController.h"
#import "TranscriptController.h"
#import "Utils.h"

#define MAX_FILES_TO_OPEN 4

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

static bool _doAbsolutePath(MimsyPath* path, int line, int col)
{
	bool opened = false;
	
	if ([path isAbsolute])
	{
		BOOL isDir = FALSE;
		if ([[NSFileManager defaultManager] fileExistsAtPath:path.asString isDirectory:&isDir] && !isDir)
		{
			opened = [OpenFile tryOpenPath:path atLine:line atCol:col withTabWidth:1];
		}
		else if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath:path.asString])
		{
			opened = [OpenFile tryOpenPath:path atLine:line atCol:col withTabWidth:1];
		}
	}
	
	return opened;
}

// If the name is an absolute path then we can open it with Mimsy if it's
// a file type we handle or launch it with an external app if not.
static bool _openAbsolutePath(MimsyPath* path, int line, int col)
{
	bool opened = false;
	
	if (_doAbsolutePath(path, line, col))
	{
		LOG("Text:Verbose", "opened using absolute path");
		opened = true;
	}
	
	return opened;
}

static bool _openRelativePath(MimsyPath* path, int line, int col)
{
	__block bool opened = false;
	
	if (![path isAbsolute])
	{
		DirectoryController* controller = [DirectoryController getCurrentController];
		if (controller)
		 {
             MimsyPath* candidate = [controller.path appendWithPath:path];
			 if (_doAbsolutePath(candidate, line, col))
			 {
				 LOG("Text:Verbose", "opened using relative path");
				 opened = true;
			 }
		 }
	}
	
	return opened;
}

static void _addLocalPaths(MimsyPath* dir, MimsyPath* path, NSMutableArray* normalFiles, NSMutableArray* hiddenFiles)
{
    [Utils enumerateDeepDir:dir glob:nil error:NULL block:^(MimsyPath* item, bool* stop)
     {
         UNUSED(stop);
         NSRange range = [item.asString rangeOfString:path.asString];
         if (range.location != NSNotFound)
         {
             NSString* name = [item lastComponent];
             if ([name startsWith:@"."])
                 [hiddenFiles addObject:item];
             else
                 [normalFiles addObject:item];
         }
     }];
}

// We assume that if we can find a match under the current directory that is what the user
// wants to open. (And we do a slow manual search because the locate command isn't always
// available, and even when it is, it does not match the current file system state).
static bool _openLocalPath(MimsyPath* path, int line, int col)
{
	__block bool opened = false;
	
	if (![path isAbsolute] && path.asString.length > 2)		// don't do something lame like open all files with "e"
	{
		DirectoryController* controller = [DirectoryController getCurrentController];
		if (controller)
		{
            NSMutableArray* normalFiles = [NSMutableArray new];
            NSMutableArray* hiddenFiles = [NSMutableArray new];
            
            _addLocalPaths(controller.path, path, normalFiles, hiddenFiles);
            for (NSString* extra in [controller.settings stringValues:@"ExtraDirectory"])
            {
                MimsyPath* dir = [[MimsyPath alloc] initWithString:extra];
                _addLocalPaths(controller.path, dir, normalFiles, hiddenFiles);
            }
            
            // Only open hidden files if there are no normal files to open.
            if (normalFiles.count == 0)
                normalFiles = hiddenFiles;
            
            if (normalFiles.count <= MAX_FILES_TO_OPEN)
            {
                for (MimsyPath* item in normalFiles)
                {
                    if (_doAbsolutePath(item, line, col))
                    {
                        LOG("Text:Verbose", "opened using local path");
                        opened = true;
                    }
                }
            }
		}
	}
	
	return opened;
}

static NSArray<NSString*>* _locateFiles(MimsyPath* path)
{
	// Unlike the other implementations of open selection here we only use
	// the file name component of the path we're trying to open. We do this
	// because it's fairly common to try and locate paths like <AppKit/NSResponder.h>
	// which are links to paths like /System/Library/Frameworks/AppKit.framework/Versions/C/Headers/NSResponder.h
	NSArray* components = [path components];
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
	NSError* err = [Utils run:task stdout:&stdout stderr:&stderr timeout:MainThreadTimeOut];
	
	if (!err)
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

static bool _openAllLocatedFiles(NSArray<NSString*>* files, int line, int col)
{
	bool opened = false;

	for (NSString* path in files)
	{
		if (_doAbsolutePath([[MimsyPath alloc] initWithString:path], line, col))
		{
			LOG("Text:Verbose", "opened using located path");
			opened = true;
		}
	}
	
	return opened;
}

static bool _selectLocatedFiles(NSArray<NSString*>* files, int line, int col)
{
	__block bool opened = false;

	NSArray* reversed = files;
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
	if ([app.layeredSettings boolValue:@"ReversePaths" missing:true])
	{
		reversed = [files map:
					 ^id(id element)
					 {
						 return [element reversePath];
					 }];
	}
	
	SelectNameController* controller = [[SelectNameController alloc] initWithTitle:@"Open Selection" names:reversed];
	(void) [NSApp runModalForWindow:controller.window];
	
	if (controller.selectedRows)
	{
		[controller.selectedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL* stop)
		 {
			 UNUSED(stop);
			 if (_doAbsolutePath([[MimsyPath alloc] initWithString:files[index]], line, col))
			 {
				 LOG("Text:Verbose", "opened %s", [files[index] UTF8String]);
				 opened = true;
			 }
			 
		 }];
	}
	
	// Even if the user cancelled he still has had a chance to handle the
	// files so we don't want to do anything further.
	return true;
}

static bool _openLocatedFiles(NSArray<NSString*>* files, int line, int col)
{
	bool opened = false;
	
	// First try and open files within the preferred directories.
	DirectoryController* controller = [DirectoryController getCurrentController];
	if (controller)
	{
		Glob* ignored = controller.ignoredPaths;
		files = [files filteredArrayUsingBlock:^bool(id element)
		{
		   return ![ignored matchName:element];
		}];

		Glob* preferred = controller.preferredPaths;
		NSArray<NSString*>* candidates = [files filteredArrayUsingBlock:^bool(id element)
		{
			return [preferred matchName:element];
		}];

		if (candidates.count <= MAX_FILES_TO_OPEN)
			opened = _openAllLocatedFiles(candidates, line, col);
	}
	
	// If we couldn't do that and we have a small number of files
	// then just open them all.
	if (!opened)
		if (files.count <= MAX_FILES_TO_OPEN)
			opened = _openAllLocatedFiles(files, line, col);
	
	// Otherwise pop up a dialog and let the user select which he wants
	// to open.
	if (!opened)
		opened = _selectLocatedFiles(files, line, col);
	
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
}

bool openLocalPath(MimsyPath* path)
{
    int line = -1, col = -1;

    bool found = false;
    if (!found)
        found = _openRelativePath(path, line, col);
    
    if (!found)
        found = _openLocalPath(path, line, col);
    
    return found;
}

static bool _openFile(NSString* text, NSUInteger location, NSUInteger length)
{
	bool found = false;

	NSString* path = [text substringWithRange:NSMakeRange(location, length)];
	if (![path contains:@"://"] && [path localizedCaseInsensitiveCompare:@"http"] != NSOrderedSame)		// don't attempt to open stuff like http://blah as a file (especially bad with _locateFiles)
	{
		LOG("Text:Verbose", "trying path '%s'", path.UTF8String);
		
		int line = -1, col = -1;
		_getLineAndCol(text, location, length, &line, &col);
		
		// We don't want to try paths like "//code.google.com/p/mobjc/w/list" because
		// we'll find "/Developer/SDKs/MacOSX10.5.sdk/usr/include/c++/4.0.0/list".
		if (![path startsWith:@"//"])
		{
            MimsyPath* p = [[MimsyPath alloc] initWithString:path];
            
			if (!found)
				found = _openAbsolutePath(p, line, col);
			
			if (!found)
				found = _openRelativePath(p, line, col);
			
			if (!found)
				found = _openLocalPath(p, line, col);
			
			if (!found)
			{
				NSArray<NSString*>* candidates = _locateFiles(p);

				if (candidates.count > 0)
					found = _openLocatedFiles(candidates, line, col);
				else
					LOG("Text:Verbose", "open using locate failed (no candidates)");
			}
		}
	}
	
	return found;
}

static bool _openHtml(NSString* text, NSUInteger location, NSUInteger length)
{
	NSString* path = [text substringWithRange:NSMakeRange(location, length)];
	LOG("Text:Verbose", "trying URL '%s'", path.UTF8String);
	
	bool opened = false;
	
	NSURL* url = [NSURL URLWithString:path];
	if (url)
	{
		[[NSWorkspace sharedWorkspace] openURL:url];
		opened = true;
	}
	else
	{
		LOG("Text:Verbose", "failed to create an url");
	}
		
	return opened;
}

// Here are some test cases which should work:
// source/plugins/find/Find.cs							relative path (this should work as well for files not in the locate db)
// DatabaseTest.cs										local file
// <AppKit/NSResponder.h>								non-local relative path
// /Users/jessejones/Source/Continuum/source/plugins/find/AssemblyInfo.cs		absolute path
// http://dev.mysql.com/tech-resources/articles/why-data-modeling.html			url
// http://en.wikipedia.org/wiki/Html#HTTP				relative url
// NSWindow.h											file in preferred directory
// c#.cs												file not in preferred directory
bool openTextRange(NSTextStorage* storage, NSRange range)
{
	bool opened = false;
	LOG("Text", "trying to open a selection");
	
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

bool openPath(NSString* path)
{
    bool opened = false;
    LOG("Text", "trying to open path");
    
    if (!opened)
        opened = _openFile(path, 0, path.length);
    
    if (!opened)
        opened = _openHtml(path, 0, path.length);
    
    return opened;
}

