#import "Balance.h"

#import "Logger.h"
#import "UIntVector.h"

static bool _closesBrace(NSString* text, NSUInteger openIndex, NSUInteger charIndex)
{
	unichar open = [text characterAtIndex:openIndex];
	unichar ch = [text characterAtIndex:charIndex];
	
	if (open == '(')
		return ch == ')';
	
	else if (open == '[')
		return ch == ']';
	
	else if (open == '{')
		return ch == '}';
	
	return false;
}

static struct UIntVector _findBraces(NSString* text, NSRange range, IsBrace isOpenBrace, IsBrace isCloseBrace)
{
	struct UIntVector braces = newUIntVector();
	
	for (NSUInteger i = range.location; i < range.location + range.length; ++i)
	{
		if (isOpenBrace(i))
		{
			pushUIntVector(&braces, i);
		}
		else if (isCloseBrace(i))
		{
			if (braces.count > 0 && _closesBrace(text, braces.data[braces.count - 1], i) && isOpenBrace(braces.data[braces.count - 1]))
				popUIntVector(&braces);
			else
				pushUIntVector(&braces, i);
		}
	}
	
	return braces;	
}

NSRange balance(NSString* text, NSRange range, IsBrace isOpenBrace, IsBrace isCloseBrace)
{
	NSRange result = NSMakeRange(range.location, range.length);
	
	// First we need to get a list of all of the braces in the range which are not paired up.
	struct UIntVector braces = _findBraces(text, range, isOpenBrace, isCloseBrace);
	
	// Then we need to expand the range to the left until we hit an open brace
	// which isn't closed within the range.
	while (result.location > 0)
	{
		result.location -= 1;
		result.length += 1;
		
		if (isOpenBrace(result.location))
		{
			if (braces.count > 0 && _closesBrace(text, result.location, braces.data[0]) && isCloseBrace(braces.data[0]))
			{
				removeAtUIntVector(&braces, 0);
			}
			else
			{
				insertAtUIntVector(&braces, 0, result.location);
				break;
			}
		}
		else if (isCloseBrace(result.location))
		{
			insertAtUIntVector(&braces, 0, result.location);
		}
	}
	
	// Finallly we need to expand the range right until we close the new brace.
	if (braces.count > 0 && isOpenBrace(braces.data[0]))
	{
		while (result.location + result.length < text.length && braces.count > 0)
		{
			result.length += 1;
			
			NSUInteger index = result.location + result.length - 1;
			if (isOpenBrace(index))
			{
				pushUIntVector(&braces, index);
			}
			else if (isCloseBrace(index))
			{
				if (_closesBrace(text, braces.data[braces.count - 1], index) && isOpenBrace(braces.data[braces.count - 1]))
					(void) popUIntVector(&braces);
				else
					break;
			}
		}
		
		if (braces.count != 0)
			result = NSMakeRange(0, 0);
	}
	else if (NSIntersectionRange(result, range).length == 0 || !isOpenBrace(result.location))
		result = NSMakeRange(0, 0);
	
//	LOG_DEBUG("Text", "%s at %s => %s", STR(text), STR(NSStringFromRange(range)), STR(NSStringFromRange(result)));
	
	freeUIntVector(&braces);
	
	return result;
}

static NSUInteger _balanceLeft(NSString* text, NSUInteger index, bool* foundOpenBrace, IsBrace isOpenBrace, IsBrace isCloseBrace)
{
	NSUInteger openIndex = 0;
	
	NSUInteger i = index;
	struct UIntVector close = newUIntVector();
	while (i < text.length)
	{
		if (isCloseBrace(i))
		{
			pushUIntVector(&close, i);
		}
		else if (close.count > 0 && _closesBrace(text, i, close.data[close.count - 1]) && isOpenBrace(i))
		{
			popUIntVector(&close);
			
			if (close.count == 0)
				break;
		}
		else if (isOpenBrace(i))
		{
			break;
		}
		
		--i;
	}
	
	if (close.count == 0)
	{
		*foundOpenBrace = true;
		openIndex = i;
	}
//	LOG_DEBUG("Text", "%s at %lu => %lu", STR(text), (unsigned long) index, (unsigned long) openIndex);
	
	freeUIntVector(&close);
	
	return openIndex;
}

static NSUInteger _balanceRight(NSString* text, NSUInteger index, bool* foundCloseBrace, IsBrace isOpenBrace, IsBrace isCloseBrace)
{
	NSUInteger closeIndex = 0;
	
	NSUInteger i = index;
	struct UIntVector open = newUIntVector();
	while (i < text.length)
	{
		if (isOpenBrace(i))
		{
			pushUIntVector(&open, i);
		}
		else if (open.count > 0 && _closesBrace(text, open.data[open.count - 1], i) && isCloseBrace(i))
		{
			popUIntVector(&open);
			
			if (open.count == 0)
				break;
		}
		else if (isCloseBrace(i))
		{
			break;
		}
		
		++i;
	}
	
	if (open.count == 0)
	{
		*foundCloseBrace = true;
		closeIndex = i;
	}
//	LOG_DEBUG("Text", "%s at %lu => %lu", STR(text), (unsigned long) index, (unsigned long) closeIndex);
	
	freeUIntVector(&open);
	
	return closeIndex;
}

NSUInteger tryBalance(NSString* text, NSUInteger index, bool* indexIsOpenBrace, bool* indexIsCloseBrace, bool* foundOtherBrace, IsBrace isOpenBrace, IsBrace isCloseBrace)
{
	*indexIsOpenBrace = index > 0 && isOpenBrace(index-1);
	*indexIsCloseBrace = index < text.length && isCloseBrace(index);
	*foundOtherBrace = false;
	
	NSUInteger otherIndex = 0;
	if (*indexIsCloseBrace)
		otherIndex = _balanceLeft(text, index, foundOtherBrace, isOpenBrace, isCloseBrace);
	else if (*indexIsOpenBrace)
		otherIndex = _balanceRight(text, index-1, foundOtherBrace, isOpenBrace, isCloseBrace);
	
	return otherIndex;	
}

NSRange tryBalanceRange(NSString* text, NSRange range, IsBrace isOpenBrace, IsBrace isCloseBrace)
{
	NSRange result = NSMakeRange(0, 0);
	
	if (range.length == 1)
	{
		bool indexIsOpenBrace = range.location < text.length && isOpenBrace(range.location);
		bool indexIsCloseBrace = range.location < text.length && isCloseBrace(range.location);
		bool foundOtherBrace = false;
		
		if (indexIsCloseBrace)
		{
			NSUInteger otherIndex = _balanceLeft(text, range.location, &foundOtherBrace, isOpenBrace, isCloseBrace);
			result = NSMakeRange(otherIndex, range.location - otherIndex + 1);
		}
		else if (indexIsOpenBrace)
		{
			NSUInteger otherIndex = _balanceRight(text, range.location, &foundOtherBrace, isOpenBrace, isCloseBrace);
			result = NSMakeRange(range.location, otherIndex+1 - range.location);
		}
	}
	
	return result;
	
}
