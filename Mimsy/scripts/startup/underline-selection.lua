-- If the current selection is an identifier then underline other occurrences of the identifier.
word = nil

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
				doc:setunderline(i, j - i + 1, 'thick', 'solid', 'blue')
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
-- underline what is selected (but not the selection)
-- try using "keyword color" and "string color"
-- maybe add "selection color"
-- abort if selection is not all identifier style
-- don't style words that are also identifiers
-- need to bail if the document has no language
-- can we only style the visible text?