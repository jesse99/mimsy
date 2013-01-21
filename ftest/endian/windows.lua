-- Verify that Mimsy is able to load and save windows line endian files.
function savedDoc(doc)
	local fname = '/tmp/windows2.txt'
	local file = io.open(fname, 'r')
	local contents = file:read('*a')
	file:close(file)
	
	-- saved documents use original endian
	local expected = 'Hello\r\nWorld\r\n';
	if contents == expected then
		ftest:passed()
	else
		ftest:failed(string.format('expected %q but found %q', expected, contents))
	end
end

function openedDoc(doc)
	local data = doc:data()
	doc:close()
	
	-- loaded documents always use Unix endian
	local expected = 'Hello\nWorld\n';
	if data == expected then
		doc:saveas('/tmp/windows2.txt', nil, 'savedDoc', 'failed')
	else
		ftest:failed(string.format('expected %q but found %q', expected, data))
	end
end

function failed(reason)
	ftest:failed(reason)
end

local fname = '/tmp/windows.txt'
local file = io.open(fname, 'w')
file:write('Hello\r\nWorld\r\n')
file:close(file)

app:openfile(fname, 'openedDoc', 'failed')
