#import "Balance.h"

#import "Logger.h"
#import "UnicharVector.h"

static bool _isOpenBrace(unichar ch)
{
	return ch == '(' || ch == '[' || ch == '{';	
}

static bool _isCloseBrace(unichar ch)
{
	return ch == ')' || ch == ']' || ch == '}';
}

static bool _closesBrace(unichar open, unichar ch)
{
	if (open == '(')
		return ch == ')';
	
	else if (open == '[')
		return ch == ']';
	
	else if (open == '{')
		return ch == '}';
	
	return false;
}

static struct UnicharVector _findBraces(NSString* text, NSRange range)
{
	struct UnicharVector braces = newUnicharVector();
	
	for (NSUInteger i = range.location; i < range.location + range.length; ++i)
	{
		unichar ch = [text characterAtIndex:i];
		if (_isOpenBrace(ch))
		{
			pushUnicharVector(&braces, ch);
		}
		else if (_isCloseBrace(ch))
		{
			if (braces.count > 0 && _closesBrace(braces.data[braces.count - 1], ch))
				popUnicharVector(&braces);
			else
				pushUnicharVector(&braces, ch);
		}
	}
	
	return braces;	
}

NSRange balance(NSString* text, NSRange range)
{
	NSRange result = NSMakeRange(range.location, range.length);
	
	// First we need to get a list of all of the braces in the range which are not paired up.
	struct UnicharVector braces = _findBraces(text, range);
	
	// Then we need to expand the range to the left until we hit an open brace
	// which isn't closed within the range.
	while (result.location > 0)
	{
		result.location -= 1;
		result.length += 1;
		
		unichar ch = [text characterAtIndex:result.location];
		if (_isOpenBrace(ch))
		{
			if (braces.count > 0 && _closesBrace(ch, braces.data[0]))
			{
				removeAtUnicharVector(&braces, 0);
			}
			else
			{
				insertAtUnicharVector(&braces, 0, ch);
				break;
			}
		}
		else if (_isCloseBrace(ch))
		{
			insertAtUnicharVector(&braces, 0, ch);
		}
	}
	
	// Finallly we need to expand the range right until we close the new brace.
	if (braces.count > 0 && _isOpenBrace(braces.data[0]))
	{
		while (result.location + result.length < text.length && braces.count > 0)
		{
			result.length += 1;
			
			unichar ch = [text characterAtIndex:result.location + result.length - 1];
			if (_isOpenBrace(ch))
			{
				pushUnicharVector(&braces, ch);
			}
			else if (_isCloseBrace(ch))
			{
				if (_closesBrace(braces.data[braces.count - 1], ch))
					(void) popUnicharVector(&braces);
				else
					break;
			}
		}
		
		if (braces.count != 0)
			result = NSMakeRange(0, 0);
	}
	else if (NSIntersectionRange(result, range).length == 0 || !_isOpenBrace([text characterAtIndex:result.location]))
		result = NSMakeRange(0, 0);
	
//	LOG_DEBUG("Text", "%s at %s => %s", STR(text), STR(NSStringFromRange(range)), STR(NSStringFromRange(result)));
	
	freeUnicharVector(&braces);
	
	return result;
}

static NSUInteger _balanceLeft(NSString* text, NSUInteger index, bool* foundOpenBrace)
{
	NSUInteger openIndex = 0;
	
	NSUInteger i = index;
	struct UnicharVector close = newUnicharVector();
	while (i < text.length)
	{
		unichar ch = [text characterAtIndex:i];
		if (_isCloseBrace(ch))
		{
			pushUnicharVector(&close, ch);
		}
		else if (close.count > 0 && _closesBrace(ch, close.data[close.count - 1]))
		{
			popUnicharVector(&close);
			
			if (close.count == 0)
				break;
		}
		else if (_isOpenBrace(ch))
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
	
	freeUnicharVector(&close);
	
	return openIndex;
}

static NSUInteger _balanceRight(NSString* text, NSUInteger index, bool* foundCloseBrace)
{
	NSUInteger closeIndex = 0;
	
	NSUInteger i = index;
	struct UnicharVector open = newUnicharVector();
	while (i < text.length)
	{
		unichar ch = [text characterAtIndex:i];
		if (_isOpenBrace(ch))
		{
			pushUnicharVector(&open, ch);
		}
		else if (open.count > 0 && _closesBrace(open.data[open.count - 1], ch))
		{
			popUnicharVector(&open);
			
			if (open.count == 0)
				break;
		}
		else if (_isCloseBrace(ch))
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
	
	freeUnicharVector(&open);
	
	return closeIndex;
}

NSUInteger tryBalance(NSString* text, NSUInteger index, bool* indexIsOpenBrace, bool* indexIsCloseBrace, bool* foundOtherBrace)
{
	*indexIsOpenBrace = index > 0 && _isOpenBrace([text characterAtIndex:index-1]);
	*indexIsCloseBrace = index < text.length && _isCloseBrace([text characterAtIndex:index]);
	*foundOtherBrace = false;
	
	NSUInteger otherIndex = 0;
	if (*indexIsCloseBrace)
		otherIndex = _balanceLeft(text, index, foundOtherBrace);
	else if (*indexIsOpenBrace)
		otherIndex = _balanceRight(text, index-1, foundOtherBrace);
	
	return otherIndex;	
}

NSRange tryBalanceRange(NSString* text, NSRange range)
{
	NSRange result = NSMakeRange(0, 0);
	
	if (range.length == 1)
	{
		bool indexIsOpenBrace = range.location < text.length && _isOpenBrace([text characterAtIndex:range.location]);
		bool indexIsCloseBrace = range.location < text.length && _isCloseBrace([text characterAtIndex:range.location]);
		bool foundOtherBrace = false;
		
		if (indexIsCloseBrace)
		{
			NSUInteger otherIndex = _balanceLeft(text, range.location, &foundOtherBrace);
			result = NSMakeRange(otherIndex, range.location - otherIndex + 1);
		}
		else if (indexIsOpenBrace)
		{
			NSUInteger otherIndex = _balanceRight(text, range.location, &foundOtherBrace);
			result = NSMakeRange(range.location, otherIndex+1 - range.location);
		}
	}
	
	return result;
	
}
