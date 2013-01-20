-- Verify that Mimsy is able to load text documents formatted as utf-16
-- big endian.
function openedDoc(doc)
	local data = doc:data()
	doc:close()
	
	if data == 'hello\226\128\162world' then
		ftest:passed()
	else
		ftest:failed(string.format('expected "hello\226\128\162world" but found %q', data))
	end
end

function openFailed(reason)
	ftest:failed(reason)
end

-- can't use tmpfile because we need a file name
-- also lua doesn't support hex escape codes
local fname = '/tmp/utf-16-be.txt'
local file = io.open(fname, 'w')
file:write('\0h\0e\0l\0l\0o\32\34\0w\0o\0r\0l\0d')
file:close(file)

app:openfile(fname, 'openedDoc', 'openFailed')
