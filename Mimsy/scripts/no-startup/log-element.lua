-- Print the name of the element at the insertion point or the name of the element
-- corresponding to the selection (if the selection matches the entire range of the
-- element).

function logselection(doc, sloc, slen)
	local element = nil
	if slen == 0 then
		element = doc:getelementat(sloc)
	else
		element = doc:getwholeelement(sloc, slen)
	end
	if element then
		app:stdout(string.format("element = %s\n", element))
	end
end

app:addhook('text selection changed', 'logselection')
