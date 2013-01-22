-- Verify that Mimsy is able to load and save files with mixed line endian.
function savedDoc(doc)
	local fname = '/tmp/mixed2.txt'
	local file = io.open(fname, 'r')
	local contents = file:read('*a')
	file:close(file)
	
	-- saved documents use which ever endian appeared the most
	local expected = 'Hello\r\nWorld\r\n\r\n';
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
	local expected = 'Hello\nWorld\n\n';
	if data == expected then
		doc:saveas('/tmp/mixed2.txt', nil, 'savedDoc', 'failed')
	else
		ftest:failed(string.format('expected %q but found %q', expected, data))
	end
end

function failed(reason)
	ftest:failed(reason)
end

local fname = '/tmp/mixed.txt'
local file = io.open(fname, 'w')
file:write('Hello\nWorld\r\n\r\n')
file:close(file)

app:openfile(fname, 'openedDoc', 'failed')
