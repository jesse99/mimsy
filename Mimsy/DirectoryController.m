#import "DirectoryController.h"

#import "ConditionalGlob.h"
#import "ConfigParser.h"
#import "DirectoryWatcher.h"
#import "FolderItem.h"
#import "Logger.h"
#import "Paths.h"
#import "TranscriptController.h"

static NSMutableArray* _windows;

@implementation DirectoryController
{
	NSString* _path;
	FolderItem* _root;
	DirectoryWatcher* _watcher;
}

- (id)initWithDir:(NSString*)path
{
	self = [super initWithWindowNibName:@"DirectoryWindow"];
	if (self)
	{
		_path = path;
		
		if (!_windows)
			_windows = [NSMutableArray new];
		[_windows addObject:self];				// need to keep a reference to the controller around (using the window won't retain the controller)
		
		[self _loadPrefs];
		
//		m_table.setDoubleAction("doubleClicked:");
//		m_table.setTarget(this);
		
		_root = [[FolderItem alloc] initWithPath:path controller:self];
		NSOutlineView* table = self.table;
		if (table)
			[table reloadData];
		
		_watcher = [[DirectoryWatcher alloc] initWithPath:path latency:1.0 block:
			^(NSArray* paths) {[self _dirChanged:paths];}];

		[self.window setTitle:[path lastPathComponent]];
		[self.window makeKeyAndOrderFront:self];
	}
	return self;
}

- (void)windowWillClose:(NSNotification*)notification
{
	(void) notification;
	
	[_windows removeObject:self];
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
		return item == nil ? _root.name : [item name];
	else
		return item == nil ? _root.bytes : [item bytes];
}

- (void)_loadPrefs
{
	_ignores = nil;
	
	NSString* path = [_path stringByAppendingPathComponent:@".mimsy.rtf"];
	NSFileManager* fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:path])
		path = [self _installPrefFile:path];
	
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
				 else
				 {
					 NSString* mesg = [NSString stringWithFormat:@"Ignoring %s from %s", STR(entry.key), STR(path)];
					 [TranscriptController writeError:mesg];
				 }
			 }
		 ];
		
		_ignores = [[ConditionalGlob alloc] initWithGlobs:ignores];
	}
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
		
		if (item)
		{
			// Continuum used the argument to reload to manually preserve the selection.
			// But it seems that newer versions of Cocoa do a better job at preserving
			// the selection.
			if ([item reload:nil])
			{
				NSOutlineView* table = self.table;
				if (table)
					[table reloadItem:item == _root ? nil : item reloadChildren:true];
			}
		}
	}
}

@end
