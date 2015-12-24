#import "ApplyStyles.h"

#import "AppDelegate.h"
#import "AsyncStyler.h"
#import "GlyphsAttribute.h"
#import "Logger.h"
#import "StyleRuns.h"
#import "TextController.h"
#import "TextStyles.h"
#import "TextView.h"

// Syntax highlighting is difficult to do well. There are a number of competing factors
// that make it hard:
// 1) It has to be fast. There should be little or no degradation in typing speed even
// for large documents (say 5K lines of source). When the user stops typing styles
// should be rendered quickly (low tenths of seconds).
// 2) It needs to be correct. This gets especially obnoxious with stuff like strings
// which can span multiple lines.
// 3) The text cannot jump around as styles are applied.
// 4) It should be simple: it's much easier for problems to crop up with more complex
// code.
//
// Mimsy comes pretty close to meeting these goals. To a first apromiximation the order of
// operation is as follows:
// 1) When a text document with a language is changed ApplyStyles addDirtyLocation:reason:
// is called which queues up a concurrent task to associate all of the document's text
// with an element name and range.
// 2) ApplyStyles is called on the main thread with the run information.
// 3) ApplyStyles skips over any runs that were previously applied. This is much faster
// than re-applying them.
// 4) The new runs are applied from the top down using a 50ms window. Conceptually it would
// make more sense to sort the runs so that the runs closest to what the user is viewing are
// applied first, but that tends to cause the text to jump around when lines have differing
// heights.
// 5) If there are more runs to apply then queue up a block to execute on the main thread.
@implementation ApplyStyles
{
	__weak TextController* _controller;
	NSUInteger _firstDirtyLoc;
	struct StyleRunVector _appliedRuns;
	bool _queued;
	NSDictionary* _braceAttrs;
	NSUInteger _braceLeft;
	NSUInteger _braceRight;
}

- (id)init:(TextController*)controller
{
	_controller = controller;
	_appliedRuns = newStyleRunVector();
	_braceAttrs = @{NSBackgroundColorAttributeName: [NSColor selectedTextBackgroundColor]};
	return self;
}

- (void)resetStyles
{
	TextController* tmp = _controller;
	if (tmp)
	{
		NSTextStorage* storage = tmp.textView.textStorage;
		[storage setAttributes:[tmp.styles attributesForElement:@"normal"] range:NSMakeRange(0, storage.length)];
		 
		[self addDirtyLocation:0 reason:@"reset styles"];
	}
}

- (void)addDirtyLocation:(NSUInteger)loc reason:(NSString*)reason
{
	TextController* tmp = _controller;
	if (tmp && !_queued && !tmp.closed)     // called from an async thread so we can be closed
	{
		// If nothing is queued then we can apply all the runs.
		_firstDirtyLoc = NSNotFound;
		_queued = true;
        LOG("Text:Styler:Verbose", "Starting up AsyncStyler for %.1f KiB (%s)", tmp.text.length/1024.0, STR(reason));
		
		[AsyncStyler computeStylesFor:tmp.fullLanguage withText:tmp.text editCount:tmp.editCount completion:
			^(StyleRuns* runs)
			{
				TextController* tmp2 = _controller;
				if (tmp2)
				{
					[runs mapElementsToStyles:
						^id(NSString* name)
						{
							return [tmp2.styles attributesForElement:name];
						}
					];
					NSTextView* textv = tmp2.textView;
					if (textv)
						[textv setBackgroundColor:tmp2.styles.backColor];

					if (loc > 0)
						[self _skipApplied:runs];
					[self _applyRuns:runs];
				}
			}
		 ];
	}
	else
	{
		// Otherwise we can usually apply the runs up to the dirty location.
		// The exception is stuff like the user typing the end delimiter of
		// a string. In that case the queued up apply will fail for the last
		// bit of text, but because _firstDirtyLoc is set we'll cycle back
		// around to here once we hit the dirty location and fix things up
		// then.
		_firstDirtyLoc = MIN(loc, _firstDirtyLoc);
	}
}

- (void)toggleBraceHighlightFrom:(NSUInteger)from to:(NSUInteger)to on:(bool)on
{
	if (!on)
	{
		from = 0;
		to = 0;
	}
	
	if (from != _braceLeft || to != _braceRight)
	{
		if (!on || to - from > 1)
		{
			_braceLeft = from;
			_braceRight = to;
			
			// This is a bit crappy because it will re-apply all the styles.
			[self addDirtyLocation:0 reason:@"brace selection"];
		}
	}
}

// This is about 50x faster than re-applying the runs.
- (void)_skipApplied:(StyleRuns*)runs
{
	double startTime = getTime();
	
	__block NSUInteger numApplied = 0;
	[runs process:
		 ^(NSUInteger elementIndex, id style, NSRange range, bool* stop)
		 {
			 (void) style;
			 
			 NSUInteger loc = _appliedRuns.data[numApplied].range.location;
			 NSUInteger len = _appliedRuns.data[numApplied].range.length;
			 if (numApplied < _appliedRuns.count &&
				 _appliedRuns.data[numApplied].elementIndex == elementIndex &&
				 loc == range.location && len == range.length &&
				 (_braceRight == 0 || loc + len < _braceLeft))
			 {
				 ++numApplied; 
			 }
			 else
			 {
				 setSizeStyleRunVector(&_appliedRuns, numApplied);
				 *stop = true;
			 }
		 }
	 ];
	
	double elapsed = getTime() - startTime;
	LOG("Text:Styler:Verbose", "Skipped %lu runs (%.0fK runs/sec)", numApplied, (numApplied/1000.0)/elapsed);
}

- (void)_applyRuns:(StyleRuns*)runs
{
	// Corresponds to 4K runs on an early 2009 Mac Pro.
	const double MaxProcessTime = 0.050;
	
	TextController* tmp = _controller;
	if (tmp)
	{
        AppDelegate* app = [NSApp delegate];
		NSTextStorage* storage = tmp.textView.textStorage;
        NSDictionary* elementHooks = app.applyElementHooks;
		double startTime = getTime();
			
		__block NSUInteger count = 0;
		__block NSUInteger beginLoc = 0;
		__block NSUInteger endLoc = 0;
		__block NSUInteger lastLoc = 0;
		[storage beginEditing];
		[runs process:
			^(NSUInteger elementIndex, id style, NSRange range, bool* stop)
			{
				(void) elementIndex;
				
				if (beginLoc == 0)
					beginLoc = range.location;
				
				lastLoc = range.location + range.length;
				if (lastLoc < _firstDirtyLoc)
				{
					[storage removeAttribute:NSBackgroundColorAttributeName range:range];
					[storage removeAttribute:NSLinkAttributeName range:range];
					[storage removeAttribute:NSToolTipAttributeName range:range];
					
					[self _applyStyle:style index:elementIndex range:range storage:storage];
                    
                    if (elementHooks.count > 0)
                    {
                        NSString* elementName = [runs indexToName:elementIndex];
                        NSArray* hooks = elementHooks[elementName];
                        for (TextRangeBlock block in hooks)
                        {
                            block(tmp, range);
                        }
                    }
					endLoc = range.location + range.length;
					
					if (++count % 1000 == 0 && (getTime() - startTime) > MaxProcessTime)
					{
						*stop = true;
					}
				}
				else
				{
					*stop = true;
				}
			}
		];
        if (endLoc > beginLoc)
        {
            [self _applyBraceStylesAt:beginLoc length:endLoc-beginLoc storage:storage];
            [self _applyGlyphStylesAt:beginLoc length:endLoc-beginLoc storage:storage];

            if (elementHooks.count > 0)
            {
                NSRange range = NSMakeRange(beginLoc, endLoc-beginLoc);
                NSArray* hooks = elementHooks[@"*"];
                for (TextRangeBlock block in hooks)
                {
                    block(tmp, range);
                }
            }
        }
		[storage endEditing];
		
		double elapsed = getTime() - startTime;
		if (lastLoc >= _firstDirtyLoc)
		{
			// If the user has done an edit there is a very good chance he'll do another
			// so defer queuing up another styler task.
			if (count > 0)
				LOG("Text:Styler:Verbose", "Applied %lu dirty runs (%.0fK runs/sec)", count, (count/1000.0)/elapsed);
			_queued = false;
			
			TextController* tmp = _controller;
            [tmp resetTypingAttributes];
			
			dispatch_queue_t main = dispatch_get_main_queue();
			dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 100*NSEC_PER_MSEC);	// 0.1s
			dispatch_after(delay, main, ^{if (!_queued) [self addDirtyLocation:_firstDirtyLoc reason:@"still dirty"];});
		}
		else if (runs.length)
		{
			LOG("Text:Styler:Verbose", "Applied %lu runs (%.0fK runs/sec)", count, (count/1000.0)/elapsed);
			dispatch_queue_t main = dispatch_get_main_queue();
			dispatch_async(main, ^{[self _applyRuns:runs];});
		}
		else
		{
			LOG("Text:Styler:Verbose", "Applied last %lu runs (%.0fK runs/sec)", count, (count/1000.0)/elapsed);
            [tmp onAppliedStyles];
			_queued = false;
		}
		if (count > 0)
			_applied = true;
	}
}

- (void)_applyStyle:(id)style index:(NSUInteger)index range:(NSRange)range storage:(NSTextStorage*)storage
{
	if (range.location + range.length > storage.length)	// can happen if the text is edited
		return;
	if (range.length == 0)
		return;
	
	pushStyleRunVector(&_appliedRuns, (struct StyleRun) {.elementIndex = index, .range = range});
	[storage addAttributes:style range:range];
}

- (void)_applyBraceStylesAt:(NSUInteger)location length:(NSUInteger)length storage:(NSTextStorage*)storage
{
    if (_braceRight > 0)
    {
        if (location <= _braceLeft && _braceLeft < location + length)
            [storage addAttributes:_braceAttrs range:NSMakeRange(_braceLeft, 1)];
        
        if (location <= _braceRight && _braceRight < location + length)
            [storage addAttributes:_braceAttrs range:NSMakeRange(_braceRight, 1)];
    }
}

- (void)_applyGlyphStylesAt:(NSUInteger)location length:(NSUInteger)length storage:(NSTextStorage*)storage
{
    TextController* tmp = _controller;
    if (tmp)
    {
        // Mapping often want to operate on entire lines so we'll ensure that the range is a full line
        // (NSMatchingWithTransparentBounds isn't sufficient).
        while (location > 0 && [storage.string characterAtIndex:location] != '\n')
            --location;
        
        while (location + length < storage.length && [storage.string characterAtIndex:location + length - 1] != '\n')
            ++length;
        
        LOG("Text:Styler:Verbose", "removing from (%lu, %lu)", (unsigned long)location, (unsigned long)length);
        [storage removeAttribute:GlyphsAttributeName range:NSMakeRange(location, length)];
        
        for (CharacterMapping* mapping in tmp.charMappings)
        {
            [mapping.regex enumerateMatchesInString:storage.string options:NSMatchingWithTransparentBounds range:NSMakeRange(location, length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop)
             {
                 UNUSED(flags, stop);
                 
                 NSRange range = [match rangeAtIndex:mapping.regex.numberOfCaptureGroups];
                 LOG("Text:Styler:Verbose", "   adding to (%lu, %lu)", (unsigned long)range.location, (unsigned long)range.length);

                 NSDictionary* style = [tmp.styles attributesForElement:mapping.style];
                 [storage addAttributes:style range:range];
                 
                 [storage addAttributes:@{GlyphsAttributeName:mapping.glyphs} range:range];
             }];
        }
        
        // These are very awkward to handle via a regex so instead of using an extension we simply
        // hard-code them.
        if (tmp.showingLeadingTabs)
            [self _applyLeadingTabGlyphsAt:location length:length controller:tmp];

        if (tmp.showingNonLeadingTabs)
            [self _applyNonLeadingTabGlyphsAt:location length:length controller:tmp];
        
        if (tmp.showingLeadingSpaces)
            [self _applyLeadingSpaceGlyphsAt:location length:length controller:tmp];
        
        if (tmp.showingLongLines)
            [self _applyLongLineStyleAt:location length:length controller:tmp];
    }
}

- (void)_applyLeadingTabGlyphsAt:(NSUInteger)location length:(NSUInteger)length controller:(TextController*)controller
{
    NSDictionary* style = [controller.styles attributesForElement:@"warning"];
    GlyphsAttribute* glyphs = [[GlyphsAttribute alloc] initWithStyle:style chars:@"\u279C" repeat:true];    // HEAVY ROUND-TIPPED RIGHTWARDS ARROW
    
    NSUInteger offset = 0;
    while (offset < length)
    {
        if (location + offset == 0 || [controller.text characterAtIndex:location + offset - 1] == '\n')   // note that Mimsy always uses Unix line endings internally
        {
            while (offset < length)
            {
                unichar ch = [controller.text characterAtIndex:location + offset];
                if (ch == '\t')
                {
                    NSUInteger start = location + offset;
                    while (offset < length && ch == '\t')
                    {
                        ++offset;
                        ch = [controller.text characterAtIndex:location + offset];
                    }
                    
                    NSRange range = NSMakeRange(start, location + offset - start);
                    [controller.textView.textStorage addAttributes:style range:range];
                    
                    [controller.textView.textStorage removeAttribute:GlyphsAttributeName range:range];
                    [controller.textView.textStorage addAttributes:@{GlyphsAttributeName:glyphs} range:range];
                }
                else if (ch == ' ')
                {
                    ++offset;
                }
                else
                {
                    ++offset;
                    break;
                }
            }
        }
        else
        {
            ++offset;
        }
    }
}

- (void)_applyNonLeadingTabGlyphsAt:(NSUInteger)location length:(NSUInteger)length controller:(TextController*)controller
{
    NSDictionary* style = [controller.styles attributesForElement:@"warning"];
    GlyphsAttribute* glyphs = [[GlyphsAttribute alloc] initWithStyle:style chars:@"\u279C" repeat:true];    // HEAVY ROUND-TIPPED RIGHTWARDS ARROW
    
    NSUInteger offset = 0;
    while (offset < length)
    {
        unichar ch = [controller.text characterAtIndex:location + offset];
        if (ch == '\t')
        {
            if (location + offset == 0 || [controller.text characterAtIndex:location + offset - 1] == '\n')   // note that Mimsy always uses Unix line endings internally
            {
                while (offset < length && ch == '\t')
                {
                    ++offset;
                    ch = [controller.text characterAtIndex:location + offset];
                }
            }
            else
            {
                NSUInteger start = location + offset;
                while (offset < length && ch == '\t')
                {
                    ++offset;
                    ch = [controller.text characterAtIndex:location + offset];
                }
                
                NSRange range = NSMakeRange(start, location + offset - start);
                [controller.textView.textStorage addAttributes:style range:range];
                
                [controller.textView.textStorage removeAttribute:GlyphsAttributeName range:range];
                [controller.textView.textStorage addAttributes:@{GlyphsAttributeName:glyphs} range:range];
            }
            
        }
        else
        {
            ++offset;
        }
    }
}

- (void)_applyLeadingSpaceGlyphsAt:(NSUInteger)location length:(NSUInteger)length controller:(TextController*)controller
{
    NSDictionary* style = [controller.styles attributesForElement:@"warning"];
    GlyphsAttribute* glyphs = [[GlyphsAttribute alloc] initWithStyle:style chars:@"\u2022" repeat:true];    // BULLET
    
    NSUInteger offset = 0;
    while (offset < length)
    {
        NSUInteger lineStart = location + offset;
        if (lineStart == 0 || [controller.text characterAtIndex:lineStart - 1] == '\n')   // note that Mimsy always uses Unix line endings internally
        {
            while (offset < length)
            {
                unichar ch = [controller.text characterAtIndex:location + offset];
                if (ch == '\t')
                {
                    ++offset;
                }
                else if (ch == ' ')
                {
                    NSUInteger start = location + offset;
                    while (offset < length && ch == ' ')
                    {
                        ++offset;
                        if (location + offset < controller.text.length)
                            ch = [controller.text characterAtIndex:location + offset];
                        else
                            ch = '\x0';
                    }
                    
                    // Allow leading spaces before multi-line C-style comments.
                    if (ch != '*')
                    {
                        // We highlight spaces at the very start of a line and spaces between tabs,
                        // but not spaces following tabs.
                        if (start == lineStart || ch == '\t')
                        {
                            NSRange range = NSMakeRange(start, location + offset - start);
                            [controller.textView.textStorage addAttributes:style range:range];
                            
                            [controller.textView.textStorage removeAttribute:GlyphsAttributeName range:range];
                            [controller.textView.textStorage addAttributes:@{GlyphsAttributeName:glyphs} range:range];
                        }
                    }
                }
                else
                {
                    ++offset;
                    break;
                }
            }
        }
        else
        {
            ++offset;
        }
    }
}

- (void)_applyLongLineStyleAt:(NSUInteger)location length:(NSUInteger)length controller:(TextController*)controller
{
    unsigned int tabWidth = (unsigned int) [controller.settings intValue:@"TabWidth" missing:4];
    int maxWidth = [controller.settings intValue:@"MaxLineWidth" missing:80];
    bool useTabWidth = [controller.settings boolValue:@"LongLineIncludesTabWidth" missing:false];
    
    NSUInteger offset = 0;
    while (offset < length)
    {
        NSUInteger lineStart = location + offset;
        if (lineStart == 0 || [controller.text characterAtIndex:lineStart - 1] == '\n')   // note that Mimsy always uses Unix line endings internally
        {
            NSUInteger longStart = 0;
            NSUInteger length = 0;
            while (location + offset < controller.text.length)
            {
                unichar ch = [controller.text characterAtIndex:location+offset];
                ++offset;

                if (ch == '\n')
                {
                   break;
                }
                else
                {
                    if (ch == '\t' && useTabWidth)
                        length += tabWidth;
                    else
                        length += 1;
                    
                    if (length > maxWidth && longStart == 0)
                        longStart = location + offset - 1;
                }
            }
            
            if (longStart > 0)
            {
                NSRange range = NSMakeRange(longStart, location + offset - longStart);
                [controller.textView.textStorage removeAttribute:NSForegroundColorAttributeName range:range];
                [controller.textView.textStorage addAttributes:@{NSForegroundColorAttributeName:[NSColor redColor]} range:range];
            }
        }
        else
        {
            ++offset;
        }
    }
}

@end
