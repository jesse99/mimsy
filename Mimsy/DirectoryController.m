#import "DirectoryController.h"

#import "AppDelegate.h"
#import "Builders.h"
#import "BuildOptionsController.h"
#import "ConditionalGlob.h"
#import "ConfigParser.h"
#import "DirectoryWatcher.h"
#import "FileItem.h"
#import "FolderItem.h"
#import "Logger.h"
#import "Mimsy-Swift.h"
#import "OpenFile.h"
#import "Paths.h"
#import "Plugins.h"
#import "TextController.h"
#import "TranscriptController.h"
#import "UpdateConfig.h"
#import "Utils.h"

static NSMutableArray* _controllers;
static DirectoryController* _lastBuilt;

@implementation DirectoryController
{
	MimsyPath* _thePath;
	FolderItem* _root;
	DirectoryWatcher* _watcher;
	NSDictionary* _dirAttrs;
	NSDictionary* _fileAttrs;
	NSDictionary* _sizeAttrs;
	NSDictionary* _globs;		// Glob => NSDictionary (text attributes)
	NSArray* _openWithMimsy;	// [Glob]
	NSRegularExpression* _copyRe;
	NSDictionary* _builderInfo;
	NSDictionary* _buildVars;	// environment variable name => value
	NSString* _defaultTarget;
	bool _closing;				// need this for leaks ftest
	NSTask* _buildTask;
	BuildOptionsController* _optionsController;
	NSMutableArray* _targets;
	NSMutableArray* _flags;
    Settings* _layeredSettings;
    NSMutableDictionary* _buildItems;
    NSDate* _prefModTime;
    NSDate* _builderModTime;
}

+ (DirectoryController*)getCurrentController
{
	// Iterate through all the windows until we find a sensible candidate,
	for (NSWindow* window in [NSApp orderedWindows])
	{
		if (window.isVisible && window.windowController)	// note that we don't consider isMiniaturized windows
		{
			id candidate = window.windowController;
			
			// if it is a directory editor window then we're done,
			if ([candidate isKindOfClass:[DirectoryController class]])
			{
				return candidate;
			}
			// if it has a text window then use the associated directory window,
			else if ([candidate isKindOfClass:[TextController class]])
			{
                TextController* text = candidate;
				DirectoryController* candidate = [DirectoryController getController:text.path];
				return candidate;
			}
			// if it hides on deactivate we'll ignore it (this is for stuff like Find windows),
			else if (window.hidesOnDeactivate)
			{
			}
			else
			{
				// otherwise return whichever last did a build (useful with the transcript window).
				return _lastBuilt;
			}
		}
	}
	
	return nil;
}

+ (DirectoryController*)getController:(MimsyPath*)path
{
	path = [path standardize];
	for (DirectoryController* controller in _controllers)
	{
		if (path && !controller->_closing)
		{
			MimsyPath* candidate = [controller->_thePath standardize];
			if (candidate && [path hasRoot:candidate])
				return controller;
		}
	}
	
	return nil;
}

+ (void)enumerate:(void (^)(DirectoryController*))block
{
	for (NSWindow* window in [NSApp orderedWindows])
	{
		if (window.isVisible || window.isMiniaturized)
			if (window.windowController)
				if ([window.windowController isKindOfClass:[DirectoryController class]])
					block(window.windowController);
	}
}

+ (DirectoryController*)open:(MimsyPath*)path
{
	DirectoryController* controller = [DirectoryController getController:path];
	if (controller && !controller->_closing)
	{
		[controller.window makeKeyAndOrderFront:self];
	}
	else
	{
		controller = [[DirectoryController alloc] initWithDir:path];
	}
	
	return controller;
}

- (id)initWithDir:(MimsyPath*)path
{
	self = [super initWithWindowNibName:@"DirectoryWindow"];
	if (self)
	{
		self.window.restorationClass = [AppDelegate class];
		self.window.identifier = @"DirectoryWindow3";
		self.targetGlobs = [NSMutableArray new];
		self.flags = [NSMutableArray new];
		self.preferredPaths = [[Glob alloc] initWithGlobs:@[]];
		self.ignoredPaths = [[Glob alloc] initWithGlobs:@[]];
		_layeredSettings = [[Settings alloc] init:@".mimsy.rtf" context:self];
        _buildItems = [NSMutableDictionary new];
		
		if (!_controllers)
			_controllers = [NSMutableArray new];
		[_controllers addObject:self];				// need to keep a reference to the controller around (using the window won't retain the controller)
		
		NSOutlineView* table = self.table;
		if (table)
		{
			[table setDoubleAction:@selector(doubleClicked:)];
			[table setTarget:self];
		}
		
		if (![path.asString isEqualToString:@":restoring:"])
			[self _loadPath:path];
        
        AppDelegate* app = [NSApp delegate];
        [app invokeProjectHook:ProjectNotificationOpened project:self];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
	}
	return self;
}

- (MimsyPath* _Nonnull)path
{
    return _thePath;
}

- (id<MimsySettings> __nonnull)settings
{
    return _layeredSettings;
}

- (NSArray<MimsyPath*>* __nonnull)resolve:(NSString* __nonnull)name
{
    NSMutableArray* result = [NSMutableArray new];
    
    NSError* error = nil;
    if ([name hasPrefix:@"/"])
    {
        [Utils enumerateDeepDir:self.path glob:nil error:&error block:^(MimsyPath* item, bool* stop) {
            UNUSED(stop);
            if ([item.asString isEqualToString:name])
                [result addObject:item];
        }];
    }
    else if ([name contains:@"/"])
    {
        name = [NSString stringWithFormat:@"/%@", name];
        [Utils enumerateDeepDir:self.path glob:nil error:&error block:^(MimsyPath* item, bool* stop) {
            UNUSED(stop);
            if ([item.asString hasSuffix:name])
                [result addObject:item];
        }];
    }
    else
    {
        [Utils enumerateDeepDir:self.path glob:nil error:&error block:^(MimsyPath* item, bool* stop) {
            UNUSED(stop);
            if ([item.lastComponent isEqualToString:name])
                [result addObject:item];
        }];
    }
    
    return result;
}

- (void)windowWillClose:(NSNotification*)notification
{
	UNUSED(notification);
    
    AppDelegate* app = [NSApp delegate];
    [app invokeProjectHook:ProjectNotificationClosing project:self];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
	if (_lastBuilt == self)
		_lastBuilt = nil;
	
	_watcher = nil;
	[_controllers removeObject:self];
	self->_closing = true;
}

- (void)window:(NSWindow*)window willEncodeRestorableState:(NSCoder*)state
{
	UNUSED(window);
	
	[state encodeObject:_thePath.asString];
}

- (void)window:(NSWindow*)window didDecodeRestorableState:(NSCoder*)state
{
	UNUSED(window);
	
	NSString* object = (NSString*) [state decodeObject];
    MimsyPath* path = [[MimsyPath alloc] initWithString:object];
	[self _loadPath:path];
}

// This only checks whether the path should be opened with mimsy using info
// from the directory. Callers will typically also check to see if the file
// can be opened with a language.
- (bool)shouldOpen:(MimsyPath*)path
{
	NSString* name = [path lastComponent];
	for (Glob* glob in _openWithMimsy)
	{
		if ([glob matchName:name])
			return true;
	}
	
	return false;
}

- (id<SettingsContext>)parent
{
    AppDelegate* app = (AppDelegate*) [NSApp delegate];
    return app;
}

- (Settings*)layeredSettings
{
    return _layeredSettings;
}

- (void)doubleClicked:(id)sender
{
	UNUSED(sender);
	
	NSOutlineView* table = _table;
	if (_table)
	{
		NSArray* selectedItems = [self _getSelectedItems];
		if (selectedItems.count == 1 && [selectedItems[0] isExpandable])
		{
			FileSystemItem* item = selectedItems[0];
			if ([table isItemExpanded:item])
				[table collapseItem:item];
			else
				[table expandItem:item];
		}
		else
		{
			[self _openSelection];
		}
	}
}

- (void)deleted:(id)sender
{
	UNUSED(sender);
	
	NSArray* selectedItems = [self _getSelectedItems];
	NSArray* urls = [selectedItems map:^id(FileSystemItem* item) {return item.path.asURL;}];
	[[NSWorkspace sharedWorkspace] recycleURLs:urls completionHandler:
	 ^(NSDictionary* urls, NSError* error)
	 {
		 UNUSED(urls);
		 
		 if (!error)
		 {
			 NSOutlineView* table = _table;
			 if (_table)
				 [table deselectAll:self];
		 }
		 else
		 {
			 NSString* reason = [error localizedFailureReason];
			 NSString* mesg = [NSString stringWithFormat:@"Couldn't move the items to the trash: %@", reason];
			 [TranscriptController writeError:mesg];
		 }
	 }
	 ];
}

- (IBAction)targetChanged:(id)sender
{
	UNUSED(sender);
	
	NSPopUpButton* menu = _targetsMenu;
	if (menu)
	{
		NSString* target = [menu titleOfSelectedItem];
		
		NSError* error = nil;
		MimsyPath* path = [_thePath appendWithComponent:@".mimsy.rtf"];
		if (!updatePref(path, @"BuildTarget", target, &error))
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Couldn't set BuildTarget pref: %@", reason];
			[TranscriptController writeError:mesg];
		}
	}
}

- (void)saveBuildFlags
{
	MimsyPath* path = [_thePath appendWithComponent:@".mimsy.rtf"];
	for (NSUInteger i = 0; i < self.targetGlobs.count; ++i)
	{
		NSError* error = nil;
		NSString* value = [NSString stringWithFormat:@"%@=%@", self.targetGlobs[i], self.flags[i]];
		if (!updatePref(path, @"BuildFlag", value, &error))
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Couldn't set BuildFlag pref for %@: %@", self.targetGlobs[i], reason];
			[TranscriptController writeError:mesg];
		}
	}
}

- (void)duplicate:(id)sender
{
	UNUSED(sender);
	
	bool copied = false;
	NSOutlineView* table = _table;
	if (_table)
	{
		NSArray* selectedItems = [self _getSelectedItems];
		for (FileSystemItem* item in selectedItems)
		{
			if ([self _duplicate:item])
				copied = true;
		}
		
		// Not sure that this is the greatest thing in the world but we'll assume
		// that everything is OK if we were able to copy something. (Notable for
		// now we don't support copying directories).
		if (copied)
			[table deselectAll:self];
		else
			NSBeep();
	}
}

- (void)openDirSettings:(id)sender
{
	UNUSED(sender);
	
	MimsyPath* path = [_thePath appendWithComponent:@".mimsy.rtf"];
	(void) [OpenFile openPath:path atLine:-1 atCol:-1 withTabWidth:1];
}

- (void)openBuildFlags:(id)sender
{
	UNUSED(sender);
	
	if (!_optionsController)
		_optionsController = [BuildOptionsController new];	
	[_optionsController openWith:self];
	
	(void) [NSApp runModalForWindow:_optionsController.window];
}

- (bool)canBuild
{
	NSPopUpButton* menu = _targetsMenu;
	NSString* target = menu != nil ? [menu titleOfSelectedItem] : nil;
	return !_buildTask && target && target.length > 0;
}

- (NSString*)buildTargetName
{
	NSPopUpButton* menu = _targetsMenu;
	return menu != nil ? [menu titleOfSelectedItem] : nil;
}

- (void)buildTarget:(id)sender
{
	UNUSED(sender);
	
	NSPopUpButton* menu = _targetsMenu;
	if (menu)
	{
		NSString* target = [menu titleOfSelectedItem];
		if (target && target.length > 0)
		{
			AppDelegate* app = (AppDelegate*) [NSApp delegate];
			[app saveAllDocuments:self];
            _lastBuilt = self;

			NSString* flags = [self _findBuildFlags:target];
            NSDictionary* info = [_buildItems objectForKey:target];
            if (!info)
                info = [Builders build:_builderInfo target:target flags:flags env:_buildVars];
			[self _doBuild:info];
		}
		else
		{
			NSBeep();
		}
	}
}

- (NSString*)_findBuildFlags:(NSString*)target
{
	for (NSUInteger i = 0; i < _targetGlobs.count; ++i)
	{
		Glob* glob = _targetGlobs[i];
		if ([glob matchName:target])
			return _flags[i];
	}
	return @"";
}

- (void)cancelBuild:(id)sender
{
    UNUSED(sender);
    [_buildTask interrupt];		// this is the "polite" way to kill a task
    _buildTask = nil;
}

- (NSArray*)getHelpContext
{
	return @[@"directory editor"];
}

// This is called often (like for every click) so it has to be fast.
- (BOOL)validateToolbarItem:(NSToolbarItem*)item
{
	BOOL enabled = YES;
	
	if ([item.itemIdentifier isEqualToString:@"Build"])
	{
		enabled = _buildTask == nil;
	}
    else if ([item.itemIdentifier isEqualToString:@"Cancel"])
    {
        enabled = _buildTask != nil;
    }
	
	return enabled;
}

// This isn't called very much: typically only once when a menu is shown for
// the first time.
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	BOOL enabled = NO;
	
	SEL sel = [item action];
	if (sel == @selector(openDirSettings:))
	{
		NSString* name = [_thePath lastComponent];
		[item setTitle:[NSString stringWithFormat:@"Open %@ Settings", name]];
		enabled = YES;
	}
    else if (sel == @selector(duplicate:))
    {
        NSOutlineView* table = _table;
        if (table)
        {
            NSIndexSet* selected = [table selectedRowIndexes];
            enabled = selected.count > 0 && table.editedRow < 0;	// cocoa crashes if we do a duplicate while editing...
        }
    }
	else if ([self respondsToSelector:sel])
	{
		enabled = YES;
	}
	else if ([super respondsToSelector:@selector(validateMenuItem:)])
	{
		enabled = [super validateMenuItem:item];
	}
	
	return enabled;
}

- (NSDictionary*)getDirAttrs:(NSString*)name
{
	for (Glob* glob in _globs)
	{
		if ([glob matchName:name])
		{
			return _globs[glob];
		}
	}
	
	return _dirAttrs;
}

- (NSDictionary*)getFileAttrs:(NSString*)name
{
	for (Glob* glob in _globs)
	{
		if ([glob matchName:name])
		{
			return _globs[glob];
		}
	}
	
	return _fileAttrs;
}

- (NSDictionary*)getSizeAttrs
{
	return _sizeAttrs;
}

- (NSInteger)outlineView:(NSOutlineView*)table numberOfChildrenOfItem:(FileSystemItem*)item
{
	UNUSED(table);
	
	return (NSInteger) (item == nil ? _root.count : [item count]);
}

- (BOOL)outlineView:(NSOutlineView*)table isItemExpandable:(FileSystemItem*)item
{
	UNUSED(table);
	
	return item == nil ? YES : [item isExpandable];
}

- (id)outlineView:(NSOutlineView*)table child:(NSInteger)index ofItem:(FileSystemItem*)item
{
	UNUSED(table);
	
	return item == nil ? _root[(NSUInteger) index] : item[(NSUInteger) index];
}

- (id)outlineView:(NSOutlineView*)table objectValueForTableColumn:(NSTableColumn*)column byItem:(FileSystemItem*)item
{
	UNUSED(table);
	
	if ([column.identifier isEqualToString:@"1"])
	{
		return item == nil ? _root.name : item.name;
	}
	else
	{
		return item == nil ? _root.bytes : [item bytes];
	}
}

- (void)outlineView:(NSOutlineView*)table setObjectValue:(id)object forTableColumn:(NSTableColumn*)col byItem:(id)item
{
	UNUSED(table, col);
	
	NSString* newName = [object description];
	[self _rename:item as:newName];
}

- (CGFloat)outlineView:(NSOutlineView*)table heightOfRowByItem:(id)item
{
	NSTableColumn* col1 = [[NSTableColumn alloc] initWithIdentifier:@"1"];
	NSTableColumn* col2 = [[NSTableColumn alloc] initWithIdentifier:@"2"];
	CGFloat height = MAX([self _getItemHeight:table col:col1 item:item], [self _getItemHeight:table col:col2 item:item]);
	return height;
}

// ---- Private Methods ----------------------------------------------------------

- (void)_doBuild:(NSDictionary*)info
{
	ASSERT(_buildTask == nil);
	
	NSString* command = [NSString stringWithFormat:@"%@ %@\n", [info[@"tool"] lastPathComponent], [info[@"args"] componentsJoinedByString:@" "]];
	if (![TranscriptController empty])
		[TranscriptController writeCommand:@"\n"];
	[TranscriptController writeCommand:command];
    
	_buildTask = [NSTask new];
	[_buildTask setLaunchPath:info[@"tool"]];
	[_buildTask setCurrentDirectoryPath:info[@"cwd"]];
	[_buildTask setArguments:info[@"args"]];
	[_buildTask setEnvironment:_buildVars];
    [_buildTask setStandardOutput:[NSPipe new]];
    [_buildTask setStandardError:[NSPipe new]];
	[self _updateBuildButtons];
	
	__block NSString* stdout = nil;
	__block NSString* stderr = nil;
	__block time_t startTime = 0;
	
	dispatch_queue_t concurrent = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_async(concurrent, ^
	{
		startTime = time(NULL);
		NSError* err = [Utils run:_buildTask stdout:&stdout stderr:&stderr timeout:NoTimeOut];
		dispatch_async(main, ^
		{
		  stdout = [stdout stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		  if (stdout && stdout.length > 0)
		  {
			  [TranscriptController writeStdout:stdout];
			  [TranscriptController writeStdout:@"\n"];
		  }
		  
		  stderr = [stderr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		  if (stderr && stderr.length > 0)
		  {
			  NSRange range = [TranscriptController writeStderr:stderr];
			  [TranscriptController writeStderr:@"\n"];

              NSString* text = [[TranscriptController getString] string];
              [BuildErrors.instance parseErrors:text range:range];
              if (BuildErrors.instance.canGotoNextError)
                  [BuildErrors.instance gotoNextError];
          }
		  _buildTask = nil;
		  [self _updateBuildButtons];
		  
		  if (!err)
		  {
			  time_t elapsed = time(NULL) - startTime;
			  [TranscriptController writeStdout:[NSString stringWithFormat:@"built in %ld seconds\n", elapsed]];
		  }
		  else
		  {
			  int returncode = [err.userInfo[@"return code"] intValue];
			  NSString* name = [info[@"tool"] lastPathComponent];
			  [TranscriptController writeStderr:[NSString stringWithFormat:@"%@ exited with code %d\n", name, returncode]];
		  }
	  });
   });
}

- (void)_updateBuildButtons
{
	NSToolbarItem* button = _buildButton;
	if (button)
		[button validate];
	
	button = _cancelButton;
	if (button)
		[button validate];
}

// Continuum allowed copying of directories although I don't think I ever used it.
// If we decide to support that we'll need to set a NSFileManager delegate to allow
// control over what gets copied and use a setting to control what should not be
// copied (e.g. .svn and .git directories). (Continuum did most of that).
- (bool)_duplicate:(FileSystemItem*)item
{
	bool copied = false;
	
	if ([item isKindOfClass:[FileItem class]])
	{
		MimsyPath* oldPath = item.path;
		MimsyPath* dir = [oldPath popComponent];
		MimsyPath* newPath = [self _getDuplicatePath:dir oldName:[oldPath lastComponent]];
		
		if (newPath)
		{
			NSError* error = NULL;
			if (![[NSFileManager defaultManager] copyItemAtPath:oldPath.asString toPath:newPath.asString error:&error])
			{
				NSString* reason = [error localizedFailureReason];
				NSString* mesg = [NSString stringWithFormat:@"Failed to duplicate %@: %@", oldPath, reason];
				[TranscriptController writeError:mesg];
			}
		}
		else
		{
			NSString* mesg = [NSString stringWithFormat:@"Chouldn't find a name to use for %@", oldPath];
			[TranscriptController writeError:mesg];
		}
		
		// We may not have actually copied the file but we have fully handled it
		// so we'll do a little white lie.
		copied = true;
	}
	
	return copied;
}

- (MimsyPath*)_getDuplicatePath:(MimsyPath*)dir oldName:(NSString*)oldName
{
	NSString* ext = [oldName pathExtension];
	NSString* name = [oldName stringByDeletingPathExtension];
	
	for (NSInteger i = 1; i < 100; ++i)
	{
		NSString* newName = [self _getDuplicateFileName:name index:i];
		if (ext.length > 0)
			newName = [newName stringByAppendingPathExtension:ext];
		
		MimsyPath* newPath = [dir appendWithComponent:newName];
		if (![[NSFileManager defaultManager] fileExistsAtPath:newPath.asString])
			return newPath;
	}
	
	return nil;
}

// Note that NSWorkspaceDuplicateOperation provides a simpler way to do
// this but it doesn't work as well. For example, "foo copy 2" becomes
// "foo copy 2 copy".
- (NSString*)_getDuplicateFileName:(NSString*)oldName index:(NSInteger)count
{
	NSString* newName = oldName;
	
	if (count == 1)
	{
		if (![oldName endsWith:@" copy"] && ![oldName contains:@" copy "])
			newName = [oldName stringByAppendingString:@" copy"];
	}
	else
	{
		if (!_copyRe)
		{
			NSError* error = nil;
			_copyRe = [[NSRegularExpression alloc] initWithPattern:@" copy \\d+$" options:0 error:&error];
			ASSERT(_copyRe);
		}
		
		NSTextCheckingResult* match = [_copyRe firstMatchInString:oldName options:0 range:NSMakeRange(0, oldName.length)];
		if (match && match.range.location != NSNotFound)
		{
			NSString* replacement = [NSString stringWithFormat:@" copy %ld", count];
			newName = [oldName stringByReplacingCharactersInRange:match.range withString:replacement];
		}
		else if ([oldName endsWith:@" copy"])
		{
			newName = [oldName stringByAppendingString:[NSString stringWithFormat:@" %ld", count]];
		}
		else
		{
			newName = [oldName stringByAppendingString:[NSString stringWithFormat:@" copy %ld", count]];
		}
	}
	
	return newName;
}

- (NSArray*)_getSelectedItems
{
	__block NSMutableArray* result = [NSMutableArray new];
	
	NSOutlineView* table = self.table;
	if (table)
	{
		NSIndexSet* indexes = [table selectedRowIndexes];
		[indexes enumerateIndexesUsingBlock:
		 ^(NSUInteger index, BOOL* stop)
		 {
			 UNUSED(stop);
			 [result addObject:[table itemAtRow:(NSInteger)index]];
		 }
		 ];
	}
	
	return result;
}

- (void)_openSelection
{
	NSArray* selectedItems = [self _getSelectedItems];
	if ([OpenFile shouldOpenFiles:selectedItems.count])
	{
		for (FileSystemItem* item  in selectedItems)
		{
			if ([item.path.asString rangeOfString:@"(Autosaved)"].location == NSNotFound)
				[OpenFile openPath:item.path atLine:-1 atCol:-1 withTabWidth:1];
		}
	}
}

- (void)_rename:(FileSystemItem*)item as:(NSString*)newName
{
	MimsyPath* oldPath = item.path;
	NSString* oldName = [oldPath lastComponent];
	if (![oldName isEqualToString:newName])
	{
		MimsyPath* dir = [oldPath popComponent];
		MimsyPath* newPath = [dir appendWithComponent:newName];
		
		// TODO: need to use a sccs to do the rename (if one is present)
		NSError* error = nil;
		if (![[NSFileManager defaultManager] moveItemAtPath:oldPath.asString toPath:newPath.asString error:&error])
		{
			NSString* reason = [error localizedFailureReason];
			NSString* mesg = [NSString stringWithFormat:@"Couldn't rename %@: %@", oldName, reason];
			[TranscriptController writeError:mesg];
		}
	}
}

- (CGFloat)_getItemHeight:(NSOutlineView*)table col:(NSTableColumn*)column item:(id)item
{
	NSAttributedString* str = [self outlineView:table objectValueForTableColumn:column byItem:item];
	NSSize size = str.size;
	return size.height;
}

- (void)_loadPath:(MimsyPath*)path
{
	_thePath = path;
	[self _loadPrefs];
	[self settingsChanged:nil];
	
	_root = [[FolderItem alloc] initWithPath:path controller:self];
	NSOutlineView* table = self.table;
	if (table)
		[table reloadData];
	
	_watcher = [[DirectoryWatcher alloc] initWithPath:path latency:3.0 block:
				^(MimsyPath* path, FSEventStreamEventFlags flags) {[self _dirChanged:path flags:flags];}];
	
	_builderInfo = [Builders builderInfo:path];
    [self _loadTargets];
    
	[self.window setTitle:[path lastComponent]];
	[self.window makeKeyAndOrderFront:self];
}

- (void)_loadTargets
{
	LOG("Mimsy", "Building targets menu");
	NSPopUpButton* menu = _targetsMenu;
	if (menu)
	{
		NSString* oldSelection = [menu titleOfSelectedItem];
		if (!oldSelection)
			oldSelection = _defaultTarget;
		
        NSArray* targets = @[];
        if (_builderInfo)
            targets = [targets arrayByAddingObjectsFromArray:[Builders getTargets:_builderInfo env:_buildVars]];
        targets = [targets arrayByAddingObjectsFromArray:_buildItems.allKeys];
		[menu removeAllItems];
		
		for (NSString* target in targets)
		{
			(void) [menu addItemWithTitle:target];
		}
		
		if (oldSelection)
			[menu selectItemWithTitle:oldSelection];
		else if (targets.count > 0)
			[menu selectItemAtIndex:0];
	}
}

- (void)settingsChanged:(NSNotification*)notification
{
	UNUSED(notification);

	if (self.path)
	{
		NSArray* patterns = [_layeredSettings stringValues:@"IgnoredPath"];
		_ignoredPaths = [[Glob alloc] initWithGlobs:patterns];

		patterns = [[_layeredSettings stringValues:@"PreferredPath"] map:
			^id (NSString* glob)
			{
				if ([glob isEqualToString:@"."])
				{
                    MimsyPath* path = [self.path appendWithComponent:@"*"];
                    return path.asString;
				}
				else if ([glob isEqualToString:@".."])
				{
                    MimsyPath* path = [[self.path popComponent] appendWithComponent:@"*"];
                    return path.asString;
				}
				else
				{
					return glob;
				}
			}];
		_preferredPaths = [[Glob alloc] initWithGlobs:patterns];
        
        _buildItems = [NSMutableDictionary new];
        for (NSString* value in [_layeredSettings stringValues:@"BuildItem"])
        {
            NSArray* fields = [value componentsSeparatedByString:@"\u00A7"];
            if (fields.count >= 2)
            {
                NSDictionary* dict;
                if (fields.count > 2)
                    dict = @{@"tool": fields[1], @"args": [fields subarrayWithRange:NSMakeRange(2, fields.count - 2)], @"cwd": @"/tmp"};
                else
                    dict = @{@"tool": fields[1], @"args": @[], @"cwd": @"/tmp"};
                [_buildItems setObject:dict forKey:fields[0]];
            }
            else
            {
                NSString* mesg = [[NSString alloc] initWithFormat:@"Expected at least two fields in BuildItem '%@'.", value];
                [TranscriptController writeError:mesg];
            }
        }
    }
}

- (bool)_prefsChanged:(MimsyPath*)path
{
    bool changed = true;
    
    NSError* error = nil;
    NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path.asString error:&error];
    if (attrs)
    {
        NSDate* fileTime = attrs[NSFileModificationDate];
        changed = fileTime != nil && (_prefModTime == nil || ![fileTime isEqualToDate:_prefModTime]);
        
        _prefModTime = fileTime;
    }
    
    return changed;
}

- (void)_loadPrefs
{
    MimsyPath* path = [_thePath appendWithComponent:@".mimsy.rtf"];
    if (![self _prefsChanged:path])
        return;
    
	_ignores = nil;
	_dontIgnores = nil;
	
	NSFileManager* fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:path.asString])
		path = [self _installPrefFile:path];
	
	NSMutableDictionary* dirAttrs = [NSMutableDictionary new];
	NSMutableDictionary* fileAttrs = [NSMutableDictionary new];
	NSMutableDictionary* sizeAttrs = [NSMutableDictionary new];
	NSMutableDictionary* globs = [NSMutableDictionary new];
	NSMutableDictionary* buildVars = [NSMutableDictionary new];
	NSMutableArray* openWithMimsy = [NSMutableArray new];
	NSMutableArray* targets = [NSMutableArray new];
	NSMutableArray* flags = [NSMutableArray new];
	
	NSProcessInfo* info = [NSProcessInfo processInfo];
	[buildVars addEntriesFromDictionary:info.environment];
	LOG("Mimsy:Verbose", "default build variables:\n%s", STR(buildVars));
	
	NSAttributedString* text = [self _loadPrefFile:path];
	if (text)
	{
		NSError* error = nil;
		ConfigParser* parser = [[ConfigParser alloc] initWithContent:text.string outError:&error];
		if (!parser)
		{
			NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't parse %@:\n%@.", path, [error localizedFailureReason]];
			[TranscriptController writeError:mesg];
			return;
		}
		
		_layeredSettings = [[Settings alloc] init:@".mimsy.rtf" context:self];

		NSMutableArray* ignores = [NSMutableArray new];
		NSMutableArray* dontIgnores = [NSMutableArray new];
		[parser enumerate:
		 ^(ConfigParserEntry* entry)
		 {
			 if ([entry.key isEqualToString:@"Ignore"])
			 {
				 [ignores addObject:entry.value];
			 }
			 else if ([entry.key isEqualToString:@"DontIgnore"])
			 {
				 [dontIgnores addObject:entry.value];
			 }
			 else if ([entry.key isEqualToString:@"DirectoryStyle"])
			 {
				 NSDictionary* attrs = [text fontAttributesInRange:NSMakeRange(entry.offset, 1)];
				 [dirAttrs addEntriesFromDictionary:attrs];
			 }
			 else if ([entry.key isEqualToString:@"FileStyle"])
			 {
				 NSDictionary* attrs = [text fontAttributesInRange:NSMakeRange(entry.offset, 1)];
				 [fileAttrs addEntriesFromDictionary:attrs];
			 }
			 else if ([entry.key isEqualToString:@"SizeStyle"])
			 {
				 NSDictionary* a = [text fontAttributesInRange:NSMakeRange(entry.offset, 1)];
				 NSMutableDictionary* attrs = [NSMutableDictionary dictionaryWithDictionary:a];
				 
				 NSMutableParagraphStyle* p = [NSMutableParagraphStyle new];
				 [p setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
				 [p setAlignment:NSRightTextAlignment];
				 attrs[NSParagraphStyleAttributeName] = p;
				 
				 [sizeAttrs addEntriesFromDictionary:attrs];
			 }
			 else if ([entry.key isEqualToString:@"OpenWithMimsy"])
			 {
				 Glob* g = [[Glob alloc] initWithGlob:entry.value];
				 [openWithMimsy addObject:g];
			 }
			 else if ([entry.key isEqualToString:@"BuildEnv"])
			 {
				 NSRange range = [entry.value rangeOfString:@"="];	
				 if (range.location != NSNotFound)
				 {
					 NSString* name = [entry.value substringToIndex:range.location];
					 NSString* value = [entry.value substringFromIndex:range.location+1];
					 buildVars[name] = value;
				 }
				 else
				 {
					 NSString* mesg = [NSString stringWithFormat:@"Expected a '=' in the value for BuildEnv %@", entry.value];
					 [TranscriptController writeError:mesg];
				 }
			 }
			 else if ([entry.key isEqualToString:@"BuildFlag"])
			 {
				 NSRange range = [entry.value rangeOfString:@"="];
				 if (range.location != NSNotFound)
				 {
					 NSString* glob = [entry.value substringToIndex:range.location];
					 NSString* flag = [entry.value substringFromIndex:range.location+1];
					 [targets addObject:[[Glob alloc] initWithGlob:glob]];
					 [flags addObject:flag];
				 }
				 else
				 {
					 NSString* mesg = [NSString stringWithFormat:@"Expected a '=' in the value for BuildFlag %@", entry.value];
					 [TranscriptController writeError:mesg];
				 }
			 }
			 else if ([entry.key isEqualToString:@"BuildTarget"])
			 {
				 _defaultTarget = entry.value;
			 }
			 else if ([entry.key isEqualToString:@"GlobStyles"])
			 {
				 NSDictionary* attrs = [text fontAttributesInRange:NSMakeRange(entry.offset, 1)];
				 NSArray* patterns = [entry.value splitByChars:[NSCharacterSet whitespaceCharacterSet]];
				 for (NSString* pattern in patterns)
				 {
					 Glob* g = [[Glob alloc] initWithGlob:pattern];
					 if (!globs[g])
						 globs[g] = attrs;
					 else
						 [TranscriptController writeError:[NSString stringWithFormat:@"%@ appears twice in GlobStyles values for %@", entry.key, path]];
				 }
			 }
			 else
			 {
				 [_layeredSettings addKey:entry.key value:entry.value];
			 }
		 }
		 ];
		
		_ignores = [[ConditionalGlob alloc] initWithGlobs:ignores];
		_dontIgnores = [[ConditionalGlob alloc] initWithGlobs:dontIgnores];
	}
    
    // When we build via MImsy we don't have a terminal so there's no display either. Lieing about
    // that can cause problems, e.g. ssh won't exit properly.
    [buildVars removeObjectForKey:@"DISPLAY"];
	
	_dirAttrs = dirAttrs;
	_fileAttrs = fileAttrs;
	_sizeAttrs = sizeAttrs;
	_globs = globs;
	_buildVars = buildVars;
	_openWithMimsy = openWithMimsy;
	_targetGlobs = targets;
	_flags = flags;

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsChanged" object:self];
    [Plugins refreshSettings];
}

- (NSAttributedString*)_loadPrefFile:(MimsyPath*)path
{
	NSURL* url = path.asURL;
	
	NSError* error = nil;
	NSUInteger options = NSFileWrapperReadingImmediate | NSFileWrapperReadingWithoutMapping;
	NSFileWrapper* file = [[NSFileWrapper alloc] initWithURL:url options:options error:&error];
	if (file)
	{
		NSData* data = file.regularFileContents;
		return [[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL];
	}
	else
	{
		NSString* mesg = [[NSString alloc] initWithFormat:@"Couldn't load the styles file at %@:\n%@.", path, [error localizedFailureReason]];
		[TranscriptController writeError:mesg];
		return nil;
	}
}

- (MimsyPath*)_installPrefFile:(MimsyPath*)dst
{
	MimsyPath* src = [[Paths installedDir:@"settings"] appendWithComponent:@"directory.rtf"];
	
	NSError* error = nil;
	NSFileManager* fm = [NSFileManager defaultManager];
	if (![fm copyItemAtPath:src.asString toPath:dst.asString error:&error])
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to copy %s to %s: %s", STR(src), STR(dst), STR(reason)];
		[TranscriptController writeError:mesg];
		return src;
	}
	
	return dst;
}

- (bool)_builderChanged:(NSString*)path
{
    bool changed = false;
    
    NSError* error = nil;
    NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (attrs)
    {
        NSDate* fileTime = attrs[NSFileModificationDate];
        changed = fileTime != nil && (_builderModTime == nil || ![fileTime isEqualToDate:_builderModTime]);
        
        _builderModTime = fileTime;
    }
    
    return changed;
}

static NSString* flagsToStr(FSEventStreamEventFlags flags)
{
    NSString* result = @"";
    
    if (flags & kFSEventStreamEventFlagMustScanSubDirs)
        result = [result stringByAppendingString:@"MustScanSubDirs "];
    
    if (flags & kFSEventStreamEventFlagUserDropped)
        result = [result stringByAppendingString:@"UserDropped "];
    
    if (flags & kFSEventStreamEventFlagKernelDropped)
        result = [result stringByAppendingString:@"KernelDropped "];
    
    if (flags & kFSEventStreamEventFlagEventIdsWrapped)
        result = [result stringByAppendingString:@"EventIdsWrapped "];
    
    if (flags & kFSEventStreamEventFlagHistoryDone)
        result = [result stringByAppendingString:@"HistoryDone "];
    
    if (flags & kFSEventStreamEventFlagRootChanged)
        result = [result stringByAppendingString:@"RootChanged "];
    
    if (flags & kFSEventStreamEventFlagMount)
        result = [result stringByAppendingString:@"Mount "];
    
    if (flags & kFSEventStreamEventFlagUnmount)
        result = [result stringByAppendingString:@"Unmount "];
    
    if (flags & kFSEventStreamEventFlagItemCreated)
        result = [result stringByAppendingString:@"ItemCreated "];
    
    if (flags & kFSEventStreamEventFlagItemRemoved)
        result = [result stringByAppendingString:@"ItemRemoved "];
    
    if (flags & kFSEventStreamEventFlagItemInodeMetaMod)
        result = [result stringByAppendingString:@"ItemInodeMetaMod "];
    
    if (flags & kFSEventStreamEventFlagItemRenamed)
        result = [result stringByAppendingString:@"ItemRenamed "];
    
    if (flags & kFSEventStreamEventFlagItemModified)
        result = [result stringByAppendingString:@"ItemModified "];
    
    if (flags & kFSEventStreamEventFlagItemFinderInfoMod)
        result = [result stringByAppendingString:@"ItemFinderInfoMod "];
    
    if (flags & kFSEventStreamEventFlagItemChangeOwner)
        result = [result stringByAppendingString:@"ItemChangeOwner "];
    
    if (flags & kFSEventStreamEventFlagItemXattrMod)
        result = [result stringByAppendingString:@"ItemXattrMod "];
    
   if (flags & kFSEventStreamEventFlagItemIsFile)
        result = [result stringByAppendingString:@"ItemIsFile "];
    
    if (flags & kFSEventStreamEventFlagItemIsDir)
        result = [result stringByAppendingString:@"ItemIsDir "];
    
    if (flags & kFSEventStreamEventFlagItemIsSymlink)
        result = [result stringByAppendingString:@"ItemIsSymlink "];
    
    if (flags & kFSEventStreamEventFlagOwnEvent)
        result = [result stringByAppendingString:@"OwnEvent "];
    
    if (flags & kFSEventStreamEventFlagItemIsHardlink)
        result = [result stringByAppendingString:@"ItemIsHardlink "];
    
    if (flags & kFSEventStreamEventFlagItemIsLastHardlink)
        result = [result stringByAppendingString:@"ItemIsLastHardlink "];
    
    if (flags == kFSEventStreamEventFlagNone)
        result = [result stringByAppendingString:@"None "];
    
    return result;
}

- (void)_dirChanged:(MimsyPath*)path flags:(FSEventStreamEventFlags)flags
{
    FSEventStreamEventFlags wanted = kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRemoved | kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemModified;
    if ((flags & wanted) == 0 && flags != kFSEventStreamEventFlagNone)
        return;
    
    LOG("Mimsy", "%s dir changed %s", STR(_thePath), STR(flagsToStr(flags)));

    // Update which ever items were opened.
	FileSystemItem* item = [_root find:path];
	if (item == _root)
	{
		[self _loadPrefs];
        if (_builderInfo && _builderInfo[@"path"] && [self _builderChanged:_builderInfo[@"path"]])
            [self _loadTargets];
	}
	
	NSOutlineView* table = self.table;
	if (item)
	{
		// Continuum used the argument to reload to manually preserve the selection.
		// But it seems that newer versions of Cocoa do a better job at preserving
		// the selection.
		//
		// TODO: But it's not perfect, I have seen the find results window collapse
		// all the items after changing the styles. If it is also a problem here we
		// should write some sort of helper to reload without changing expansions.
		// But note that this is a bit more complex for find results because the
		// items are replaced with brand new items.
		if ([item reload:nil])
		{
			if (table && item != _root)
				[table reloadItem:item == _root ? nil : item reloadChildren:true];
		}
	}
	
	// If root changes we need to force a full reload (mainly because the prefs file
	// may have changed and we need to let Cocoa know if any row heights have changed).
	if (table && item == _root)
		[table reloadData];

    AppDelegate* app = [NSApp delegate];
    [app invokeProjectHook:ProjectNotificationChanged project:self];
}

@end
