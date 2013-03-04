-- Open and close a bunch of new directory windows and verify that memory usage does 
-- not go up significantly.

max_count = 3
count = 0
window = nil

stats = {}
stats['DirectoryController'] = ftest:instancecount('DirectoryController')
stats['DirectoryWindow'] = ftest:instancecount('DirectoryWindow')

function checkStats(delta)
	local err = ''
	
	for name, value in pairs(stats) do
		local expected = value + delta
		local actual = ftest:instancecount(name)
		if actual ~= expected then
			err = err .. string.format('%s was %d, but expected %d\n', name, actual, expected)
		end
	end
	
	if #err > 0 then
		error(err, 1)
	end
end

-- retain counts don't go to zero immediately so we need to defer this
function checkWindow()
	app:log(string.format("numdirwindows = %d,  numcontrollers = %d", ftest:instancecount('DirectoryWindow'), ftest:instancecount('DirectoryController')))
	checkStats(0)
	
	if count < max_count then
		app:schedule(0.0, 'createWindow')
	else
		ftest:passed()
	end
end

function closeWindow()
	checkStats(1)
	window:close()
	app:schedule(1.0, 'checkWindow')
end

function createWindow()
	window = app:opendir('/private/tmp')
	count = count + 1
	app:schedule(2.0, 'closeWindow')
end

app:schedule(0.0, 'createWindow')
