-- Verify that Mimsy is able to load text documents formatted as utf-8.
function openedDoc(doc)
	local data = doc:data()
	doc:close()
	
	if data == 'Hello\226\128\162World' then
		ftest:passed()
	else
		ftest:failed(string.format('expected "Hello\226\128\162World" but found %q', data))
	end
end

function openFailed(reason)
	ftest:failed(reason)
end

-- can't use tmpfile because we need a file name
-- also lua doesn't support hex escape codes
local fname = '/tmp/utf-8.txt'
local file = io.open(fname, 'w')
file:write('Hello\226\128\162World')	-- 'Hello World' with a bullet
file:close(file)

app:openfile(fname, 'openedDoc', 'openFailed')
