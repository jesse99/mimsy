-- Verify that Mimsy complains when opening documents with control characters.
function openedDoc(doc)
	local data = doc:data()
	doc:close()
	
	-- The document should load complete with control characters (if they are
	-- undesired users can use Find Gremlins to figure out where they are).
	local expected = 'The quick brown fox\7jumped over the lazy dog\4'
	if data == expected then
		ftest:expecterror("Found 1 '\\x07' (BELL) and 1 '\\x04' (END OF TRANSMISSION) characters")
	else
		ftest:failed(string.format('expected %q but found %q', expected, data))
	end
end

function openFailed(reason)
	ftest:failed(reason)
end

local fname = '/tmp/control-chars1.txt'
local file = io.open(fname, 'w')
file:write('The quick brown fox\7jumped over the lazy dog\4')
file:close(file)

app:openfile(fname, 'openedDoc', 'openFailed')
