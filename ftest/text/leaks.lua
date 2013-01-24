-- Open and close a bunch of new windows and verify that memory usage does not go up.
max_count = 10
count = 0
old_size = ftest:getresidentbytes()
doc = nil

function closeDoc()
	doc:close()
	local size = ftest:getresidentbytes()
	app:log(string.format('delta = %d KiB', (size - old_size)/1024))
	old_size = size
	
	if count < max_count then
		app:schedule(0.0, 'createDoc')
	else
		ftest:passed()
	end
end

function createDoc()
	doc = app:newdoc()
	count = count + 1
	app:schedule(2.0, 'closeDoc')
end

app:schedule(0.0, 'createDoc')
