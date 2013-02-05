-- If the current selection is an identifier then underline other occurrences of the identifier.

function underline(doc, loc, len)
	local index = loc
	local text = doc:data()
	while index < loc + len do
		i, j = string.find(text, "path", index, true)
		if i then
			doc:setunderline(i, j - i + 1, 'thick', 'solid', 'blue')
			index = j
		else
			break
		end
	end
end

app:addhook('apply styles', 'underline')

-- TODO:
-- underline what is selected (but not the selection)
-- try using "keyword color" and "string color"
-- maybe add "selection color"
-- abort if selection is not all identifier style
-- don't style words that are also identifiers
