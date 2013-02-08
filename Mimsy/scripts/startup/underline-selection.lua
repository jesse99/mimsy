-- If the current selection is a word then underline other occurrences of that word.
word = nil
selstart = 0

-- There is a tension between underlining what people are interested in and
-- avoiding cluttering the display. Given that people can always fallback to
-- doing an actual search this script elects to be conservative and only underlines
-- identifiers and identifier-like words.
function isword(doc, loc, len)
	local elem = doc:getwholeelement(loc, len)
	return elem == 'identifier' or elem == 'function' or elem == 'define' or elem == 'macro' or elem == 'type' or elem == 'structure' or elem == 'typedef'
end

-- Called whenever the selection changes. We do a quick check to see if the selection
-- range is sane and then stash away the selected word (or nil).
function resetselection(doc, sloc, slen)
	local newword = nil
	if slen > 0 and slen < 100 then
		if isword(doc, sloc, slen) then
			local text = doc:data()
			newword = string.sub(text, sloc, sloc + slen - 1)
		end
	end
	
	if word ~= newword then
		word = newword
		selstart = sloc
		
		-- We need to reset any underlining that may have been present
		-- and start styling the text again to apply any underling we may
		-- now have.
		doc:resetstyle()
	end
end

-- This is called after styles have been applied to a chunk of text. We find all the
-- instances of the word in the chunk and underline them if they are not the original
-- selection and not substrings of a larger identifier.
function underlineselection(doc, loc, len)
	if word then
		local index = loc
		local text = doc:data()
		while index < loc + len do
			i, j = string.find(text, word, index, true)
			if i then
				if i ~= selstart then
					if isword(doc, i, #word) then
						-- Which color to use is a bit of a sticky problem given the wide
						-- variation in style files. But the keyword color will almost always
						-- be something that stands out well.
						doc:setunderline(i, j - i + 1, 'thick', 'solid', 'keyword color')
					end
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
