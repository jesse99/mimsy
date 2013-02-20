#import "FolderItem.h"

#import "DirectoryController.h"
#import "FileItem.h"
#import "Glob.h"
#import "Logger.h"
#import "Utils.h"

@implementation FolderItem
{
	NSMutableArray* _children;
	__weak DirectoryController* _controller;
}

- (id)initWithPath:(NSString*)path controller:(DirectoryController*)controller
{
	self = [super initWithPath:path];
	_controller = controller;
	return self;
}

- (bool)isExpandable
{
	return true;
}

- (NSUInteger)count
{
	// Note that we want to defer loading children until we absolutely have
	// to so that we work better with large directory trees.
	if (!_children)
	{
		_children = [NSMutableArray new];
		[self _reload:nil];
	}

	return _children.count;
}

- (FileSystemItem*)objectAtIndexedSubscript:(NSUInteger)index
{
	if (!_children)
	{
		_children = [NSMutableArray new];
		[self _reload:nil];
	}
	
	return _children[index];
}

- (FileSystemItem*)find:(NSString*)path
{
	FileSystemItem* result = [super find:path];
	
	if (_children)
	{
		for (NSUInteger i = 0; i < _children.count && result == nil; ++i)
		{
			result = [_children[i] find:path];
		}
	}
	
	return result;
}

- (bool)reload:(NSMutableArray*)added
{
	bool changed = false;
	
	if (_children)
		changed = [self _reload:added];
	
	return changed;
}

- (bool)_reload:(NSMutableArray*)added
{
	bool changed = false;
	
	// Get the current state of the directory.
	NSArray* paths = [self _getPaths];
	
	// Remove items not in paths.
	for (NSUInteger i = 0; i < _children.count;)
	{
		if (![paths containsObject:_children[i]])
		{
			[_children removeObjectAtIndex:i];
			changed = true;
		}
		else
			++i;
	}
	
	// Reload any existing items.
	for (FileSystemItem* item in _children)
	{
		if ([item reload:added])
			changed = true;
	}
	
	// Add new items from paths.
	for (NSUInteger i = 0; i < paths.count; ++i)
	{
		NSString* path = paths[i];
		
		if (![_children containsObject:path])
		{
			BOOL isDir;
			if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
			{
				FileSystemItem* item;
				if (!isDir || [[NSWorkspace sharedWorkspace] isFilePackageAtPath:path])
					item = [[FileItem alloc] initWithPath:path];
				else
					item = [[FolderItem alloc] initWithPath:path controller:_controller];
				
				[_children addObject:item];
				if (added)
					[added addObject:item];
				
				changed = true;
			}
		}
	}
	
	// Sort all the items using a case-insensitive sort.
	if (changed)
	{
		[_children sortUsingComparator:
			^NSComparisonResult(FileSystemItem* lhs, FileSystemItem* rhs)
			{
				if (lhs && !rhs)
					return NSOrderedDescending;
				else if (!lhs && rhs)
					return NSOrderedAscending;
				else
					return [lhs.path localizedCaseInsensitiveCompare:rhs.path];
			}
		 ];
	}
	
	return changed;	
}

- (NSArray*)_getPaths
{
	__block NSMutableArray* paths = [NSMutableArray new];
	
	DirectoryController* controller = _controller;
	
	NSError* error = nil;
	bool ok = [Utils enumerateDir:self.path glob:nil error:&error block:
		^(NSString* item)
		{
			if (!controller || ![controller.ignores matchName:[item lastPathComponent]])
				[paths addObject:item];
		}
	];
	if (!ok)
	{
		// With Continuum (and Mono directory enumeration) I saw errors fairly often
		// when directories were being rebuilt as part of builds.
		NSString* reason = [error localizedFailureReason];
		LOG_ERROR("DirEditor", "Error enumerating %s: %s", STR(self.path), STR(reason));
	}
	
	return paths;
}

@end
