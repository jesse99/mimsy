-- Add special styling to TODO, FIXME, and XXX when they appear in comments.

function stylexxx(doc, loc, len, word)
	local index = loc
	local text = doc:data()
	while index < loc + len do
		i, j = string.find(text, word, index, true)
		if i then
			-- -3.0 is, more or less, bold. -5.0 is extra bold.
			doc:setstrokewidth(i, j - i + 1, -5.0)
			index = j
		else
			break
		end
	end
end

-- This is called after styles have been applied to a chunk of text. We find all the
-- instances of the word in the chunk and underline them if they are not the original
-- selection and not substrings of a larger identifier.
function styletodo(doc, loc, len)
	-- Lua does support regular expressions but they are quite weak: they don't even
	-- support the alternation operator (|).
	stylexxx(doc, loc, len, 'TODO')
	stylexxx(doc, loc, len, 'FIXME')
	stylexxx(doc, loc, len, 'XXX')
end

app:addhook('override comment style', 'styletodo')
