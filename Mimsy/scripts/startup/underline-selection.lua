-- If the current selection is an identifier then underline other occurrences of the identifier.
word = nil
selstart = 0

function resetselection(doc, sloc, slen)
	local newword = nil
	if slen > 0 and slen < 100 then
		local text = doc:data()
		newword = string.sub(text, sloc, sloc + slen - 1)
	else
		newword = nil
	end
	
	if word ~= newword then
		word = newword
		selstart = sloc
		doc:resetstyle()
	end
end

function underlineselection(doc, loc, len)
	if word then
		local index = loc
		local text = doc:data()
		while index < loc + len do
			i, j = string.find(text, word, index, true)
			if i then
				if i ~= selstart then
					doc:setunderline(i, j - i + 1, 'thick', 'solid', 'blue')
				end
				index = j
			else
				break
			end
		end
	end
end

app:addhook('text selection changed', 'resetselection')
app:addhook('apply styles', 'underlineselection')

-- TODO:
-- abort if selection is not all identifier style
-- don't style words that are also identifiers
-- need to key off words, nor partial words
-- need to match words, not partial words
-- need to bail if the document has no language
-- can we only style the visible text?