#import "SearchSite.h"

#import "AppDelegate.h"
#import "Language.h"
#import "TranscriptController.h"

@implementation SearchSite

+(void)updateMainMenu:(NSMenu*)searchMenu
{
	NSMutableArray* sources = [NSMutableArray new];
	NSMutableArray* searchers = [NSMutableArray new];
	
    [SearchSite _findSearchers:searchers sources:sources context:activeContext];
	[SearchSite _clearSearchers:searchMenu];
	[SearchSite _addSearchers:searchers sources:sources to:searchMenu];
}

+(void)appendContextMenu:(NSMenu*)menu context:(id<SettingsContext>)context
{
	NSMutableArray* sources = [NSMutableArray new];
	NSMutableArray* searchers = [NSMutableArray new];
	
    [SearchSite _findSearchers:searchers sources:sources context:context];
	[SearchSite _addSearchers:searchers sources:sources to:menu];
}

// sources is used when reporting errors within the search URL
+ (void)_findSearchers:(NSMutableArray*)searchers sources:(NSMutableArray*)sources context:(id<SettingsContext>)context
{
	[context.settings enumerate:@"SearchIn" with:
		 ^(NSString *fileName, NSString *value)
		 {
			 [sources addObject:fileName];
			 [searchers addObject:value];
		 }];
}

+ (void)_clearSearchers:(NSMenu*)searchMenu
{
	NSMenu* menu = searchMenu;
	while (menu && menu.numberOfItems > 0)
	{
		NSInteger index = menu.numberOfItems-1;
		NSMenuItem* item = [menu itemAtIndex:index];
		if (item.action == @selector(searchSite:))
			[menu removeItemAtIndex:index];
		else
			break;
	}
}

+ (void)_addSearchers:(NSArray*)searchers sources:(NSArray*)sources to:(NSMenu*)searchMenu
{
	ASSERT(searchers.count == sources.count);
	
	for (NSUInteger i = 0; i < searchers.count; ++i)
	{
		NSString* label;
		NSString* template;
		[SearchSite _extractFrom:searchers[i] label:&label andURL:&template source:sources[i]];
		
		NSString* title = [NSString stringWithFormat:@"Search in %@", label];
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(searchSite:) keyEquivalent:@""];
		[item setRepresentedObject:template];
		
		NSMenu* menu = searchMenu;
		if (menu)
			[menu addItem:item];
	}
}

// value is formatted as: [label]url with ${TEXT}
+ (void)_extractFrom:(NSString*)text label:(NSString**)label andURL:(NSString**)template source:(NSString*)source
{
	NSRange r1 = [text rangeOfString:@"["];
	NSRange r2 = [text rangeOfString:@"]"];
	NSString* error = nil;
	if (r1.location != NSNotFound && r2.location != NSNotFound && r2.location > r1.location)
	{
		NSString* name = [text substringWithRange:NSMakeRange(r1.location+1, r2.location-r1.location-1)];
		if (name.length == 0)
		{
			error = [NSString stringWithFormat:@"empty label for '%@'.", text];
			goto failed;
		}
		
		NSString* path = [text substringFromIndex:r2.location+1];
		if (![path contains:@"${TEXT}"])
		{
			error = [NSString stringWithFormat:@"expected '${TEXT}' in the url portion of '%@'.", text];
			goto failed;
		}
		
		NSString* p = [path stringByReplacingOccurrencesOfString:@"${TEXT}" withString:@"xxx"];
		NSURL* url = [NSURL URLWithString:p];
		if (!url)
		{
			error = [NSString stringWithFormat:@"expected '[label]url' but found malformed url: '%@'.", text];
			goto failed;
			
		}
		
		*label = name;
		*template = path;
	}
	else
	{
		error = [NSString stringWithFormat:@"expected '[label]url' but found: '%@'.", text];
	}
	
failed:
	if (error)
		[TranscriptController writeError:[NSString stringWithFormat:@"Failed to parse searcher from %@: %@", source, error]];
}

@end
