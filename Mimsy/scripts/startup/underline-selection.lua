-- If the current selection is a word then underline other occurrences of that word.
word = nil
selstart = 0

function iswordchar(text, i)
	if i >= 1 and i <= #text then
		local s = string.sub(text, i, i)
		if s >= 'a' and s <= 'z' then
			return true
		elseif s >= 'A' and s <= 'Z' then
			return true
		elseif s >= '0' and s <= '9' then
			return true
		elseif s == '_' then
			return true
		end
	end
	return false
end

function iswordelem(doc, i)
	local elem = doc:getelementname(i)
	return elem == 'normal' or elem == 'identifier' or elem == 'function' or elem == 'define' or elem == 'macro' or elem == 'type' or elem == 'structure' or elem == 'typedef'
end

function resetselection(doc, sloc, slen)
	local newword = nil
	-- We consider a word to:
	-- 1) Have a non-empty length and not be crazy big.
	if slen > 0 and slen < 100 then
		-- 2) Be something that we want to see other occurences of, e.g. an identifier,
		-- a function name, a type, etc.
		if iswordelem(doc, sloc) then
			-- 3) Be a full word. TODO: this won't be quite right for weird languages like
			-- objc, may want to make use of the Word element in the language file.
			local text = doc:data()
			if not iswordchar(text, sloc - 1) and not iswordchar(text, sloc + slen) then 
				newword = string.sub(text, sloc, sloc + slen - 1)
			end
		end
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
					if not iswordchar(text, i - 1) and not iswordchar(text, i + len) then 
						if iswordelem(doc, i) then
							doc:setunderline(i, j - i + 1, 'thick', 'solid', 'blue')
						end
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
