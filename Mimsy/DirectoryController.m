#import "DirectoryController.h"

#import "AppDelegate.h"
#import "Assert.h"
#import "ConditionalGlob.h"
#import "ConfigParser.h"
#import "DirectoryWatcher.h"
#import "FileItem.h"
#import "FolderItem.h"
#import "Logger.h"
#import "OpenFile.h"
#import "Paths.h"
#import "StringCategory.h"
#import "TranscriptController.h"

static NSMutableArray* _controllers;

@implementation DirectoryController
{
	NSString* _path;
	FolderItem* _root;
	DirectoryWatcher* _watcher;
	NSDictionary* _dirAttrs;
	NSDictionary* _fileAttrs;
	NSDictionary* _sizeAttrs;
	NSDictionary* _globs;		// Glob => NSDictionary
	NSArray* _openWithMimsy;	// [Glob]
	NSRegularExpression* _copyRe;
}

+ (DirectoryController*)getController:(NSString*)path
{
	path = [path stringByStandardizingPath];
	for (DirectoryController* controller in _controllers)
	{
		NSString* candidate = [controller->_path stringByStandardizingPath];
		if ([path rangeOfString:candidate].location == 0)
			return controller;
	}
	
	return nil;
}

- (id)initWithDir:(NSString*)path
{
	self = [super initWithWindowNibName:@"DirectoryWindow"];
	if (self)
	{
		self.window.restorationClass = [AppDelegate class];
		self.window.identifier = @"DirectoryWindow3";
		
		if (!_controllers)
			_controllers = [NSMutableArray new];
		[_controllers addObject:self];				// need to keep a reference to the controller around (using the window won't retain the controller)
		
		NSOutlineView* table = self.table;
		if (table)
		{
			[table setDoubleAction:@selector(doubleClicked:)];
			[table setTarget:self];
		}
		
		if (![path isEqualToString:@":restoring:"])
			[self _loadPath:path];
	}
	return self;
}

- (void)windowWillClose:(NSNotification*)notification
{
	(void) notification;
	
	[_controllers removeObject:self];
}

- (void)window:(NSWindow*)window willEncodeRestorableState:(NSCoder*)state
{
	(void) window;
	
	[state encodeObject:_path];
}

- (void)window:(NSWindow*)window didDecodeRestorableState:(NSCoder*)state
{
	(void) window;
	
	NSString* path = (NSString*) [state decodeObject];
	[self _loadPath:path];
}

// This only checks whether the path should be opened with mimsy using info
// from the directory. Callers will typically also check to see if the file
// can be opened with a language.
- (bool)shouldOpen:(NSString*)path
{
	NSString* name = [path lastPathComponent];
	for (Glob* glob in _openWithMimsy)
	{
		if ([glob matchName:name])
			return true;
	}
	
	return false;
}

- (void)doubleClicked:(id)sender
{
	(void) sender;
	
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

- (void)duplicate:(id)sender
{
	(void) sender;
	
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

- (NSDictionary*)getDirAttrs:(NSString*)path
{
	NSString* name = [path lastPathComponent];
	for (Glob* glob in _globs)
	{
		if ([glob matchName:name])
		{
			return _globs[glob];
		}
	}
	
	return _dirAttrs;
}

- (NSDictionary*)getFileAttrs:(NSString*)path
{
	NSString* name = [path lastPathComponent];
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
	(void) table;
	
	return (NSInteger) (item == nil ? _root.count : [item count]);
}

- (BOOL)outlineView:(NSOutlineView*)table isItemExpandable:(FileSystemItem*)item
{
	(void) table;
	
	return item == nil ? YES : [item isExpandable];
}

- (id)outlineView:(NSOutlineView*)table child:(NSInteger)index ofItem:(FileSystemItem*)item
{
	(void) table;
	
	return item == nil ? _root[(NSUInteger) index] : item[(NSUInteger) index];
}

- (id)outlineView:(NSOutlineView*)table objectValueForTableColumn:(NSTableColumn*)column byItem:(FileSystemItem*)item
{
	(void) table;
	
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
	(void) table;
	(void) col;
	
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

// Continuum allowed copying of directories although I don't think I ever used it.
// If we decide to support that we'll need to set a NSFileManager delegate to allow
// control over what gets copied and use a setting to control what should not be
// copied (e.g. .svn and .git directories). (Continuum did most of that).
- (bool)_duplicate:(FileSystemItem*)item
{
	bool copied = false;
	
	if ([item isKindOfClass:[FileItem class]])
	{
		NSString* oldPath = item.path;
		NSString* dir = [oldPath stringByDeletingLastPathComponent];
		NSString* newPath = [self _getDuplicatePath:dir oldName:[oldPath lastPathComponent]];
		
		if (newPath)
		{
			NSError* error = NULL;
			if (![[NSFileManager defaultManager] copyItemAtPath:oldPath toPath:newPath error:&error])
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

- (NSString*)_getDuplicatePath:(NSString*)dir oldName:(NSString*)oldName
{
	NSString* ext = [oldName pathExtension];
	NSString* name = [oldName stringByDeletingPathExtension];
	
	for (NSInteger i = 1; i < 100; ++i)
	{
		NSString* newName = [self _getDuplicateFileName:name index:i];
		newName = [newName stringByAppendingPathExtension:ext];
		
		NSString* newPath = [dir stringByAppendingPathComponent:newName];
		if (![[NSFileManager defaultManager] fileExistsAtPath:newPath])
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
			 (void) stop;
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
			if ([item.path rangeOfString:@"(Autosaved)"].location == NSNotFound)
				[OpenFile openPath:item.path atLine:-1 atCol:-1 withTabWidth:1];
			else
				NSBeep();
		}
	}
}

- (void)_rename:(FileSystemItem*)item as:(NSString*)newName
{
	NSString* oldPath = item.path;
	NSString* oldName = [oldPath lastPathComponent];
	if (![oldName isEqualToString:newName])
	{
		NSString* dir = [oldPath stringByDeletingLastPathComponent];
		NSString* newPath = [dir stringByAppendingPathComponent:newName];
		
		// TODO: need to use a sccs to do the rename (if one is present)
		NSError* error = nil;
		if (![[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error])
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

- (void)_loadPath:(NSString*)path
{
	_path = path;
	[self _loadPrefs];
	
	_root = [[FolderItem alloc] initWithPath:path controller:self];
	NSOutlineView* table = self.table;
	if (table)
		[table reloadData];
	
	_watcher = [[DirectoryWatcher alloc] initWithPath:path latency:1.0 block:
				^(NSArray* paths) {[self _dirChanged:paths];}];
	
	[self.window setTitle:[path lastPathComponent]];
	[self.window makeKeyAndOrderFront:self];
}

- (void)_loadPrefs
{
	_ignores = nil;
	
	NSString* path = [_path stringByAppendingPathComponent:@".mimsy.rtf"];
	NSFileManager* fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:path])
		path = [self _installPrefFile:path];
	
	NSMutableDictionary* dirAttrs = [NSMutableDictionary new];
	NSMutableDictionary* fileAttrs = [NSMutableDictionary new];
	NSMutableDictionary* sizeAttrs = [NSMutableDictionary new];
	NSMutableDictionary* globs = [NSMutableDictionary new];
	NSMutableArray* openWithMimsy = [NSMutableArray new];
	
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
		
		NSMutableArray* ignores = [NSMutableArray new];
		[parser enumerate:
			 ^(ConfigParserEntry* entry)
			 {
				 if ([entry.key isEqualToString:@"Ignore"])
				 {
					 [ignores addObject:entry.value];
				 }
				 else if ([entry.key isEqualToString:@"Directory"])
				 {
					 NSDictionary* attrs = [text fontAttributesInRange:NSMakeRange(entry.offset, 1)];
					 [dirAttrs addEntriesFromDictionary:attrs];
				 }
				 else if ([entry.key isEqualToString:@"File"])
				 {
					 NSDictionary* attrs = [text fontAttributesInRange:NSMakeRange(entry.offset, 1)];
					 [fileAttrs addEntriesFromDictionary:attrs];
				 }
				 else if ([entry.key isEqualToString:@"Size"])
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
				 else
				 {
					 NSDictionary* attrs = [text fontAttributesInRange:NSMakeRange(entry.offset, 1)];
					 Glob* g = [[Glob alloc] initWithGlob:entry.key];
					 if (![globs objectForKey:g])
						 globs[g] = attrs;
					 else
						[TranscriptController writeError:[NSString stringWithFormat:@"%@ appears twice in %@", entry.key, path]];
				 }
			 }
		 ];
		
		_ignores = [[ConditionalGlob alloc] initWithGlobs:ignores];
	}
	
	_dirAttrs = dirAttrs;
	_fileAttrs = fileAttrs;
	_sizeAttrs = sizeAttrs;
	_globs = globs;
	_openWithMimsy = openWithMimsy;
}

- (NSAttributedString*)_loadPrefFile:(NSString*)path
{
	NSURL* url = [NSURL fileURLWithPath:path];
	
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

- (NSString*)_installPrefFile:(NSString*)dst
{
	NSString* src = [[Paths installedDir:@"settings"] stringByAppendingPathComponent:@"directory.rtf"];
	
	NSError* error = nil;
	NSFileManager* fm = [NSFileManager defaultManager];
	if (![fm copyItemAtPath:src toPath:dst error:&error])
	{
		NSString* reason = [error localizedFailureReason];
		NSString* mesg = [NSString stringWithFormat:@"Failed to copy %s to %s: %s", STR(src), STR(dst), STR(reason)];
		[TranscriptController writeError:mesg];
		return src;
	}
	
	return dst;
}

- (void)_dirChanged:(NSArray*)paths
{
	// Update which ever items were opened.
	for (NSString* path in paths)
	{
		FileSystemItem* item = [_root find:path];
		if (item == _root)
			[self _loadPrefs];
		
		NSOutlineView* table = self.table;
		if (item)
		{
			// Continuum used the argument to reload to manually preserve the selection.
			// But it seems that newer versions of Cocoa do a better job at preserving
			// the selection.
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
	}
}

@end
