-- Open and close a bunch of new windows and verify that memory usage does not go up
-- significantly. This turned out to be quite a bit more difficult to do than I had hoped. I 
-- tried three different approaches:
--
-- 1) Verify that resident memory size doesn't increase. Unfortunately it does seem to
-- increase (but only when the script is used: not when the windows are manually opened).
--
-- 2) Verify that the malloc block counts are not strictly increasing. But even when the doc:
-- close commented out that isn't always true. For one run I got:
-- 5.449	Mimsy 	INFO	size = 23078 blocks
-- 7.467	Mimsy 	INFO	size = 23736 blocks
-- 9.484	Mimsy 	INFO	size = 24529 blocks
-- 11.498	Mimsy 	INFO	size = 25306 blocks
-- 13.512	Mimsy 	INFO	size = 23706 blocks ***
-- 15.525	Mimsy 	INFO	size = 24501 blocks
-- 17.555	Mimsy 	INFO	size = 25296 blocks
-- 19.577	Mimsy 	INFO	size = 26093 blocks
-- 21.590	Mimsy 	INFO	size = 26894 blocks
-- 23.618	Mimsy 	INFO	size = 27636 blocks
--
-- I thought about doing a linear regression and checking the slope, but even that isn't
-- entirely straight-forward because there does seem to be some small growth (tho I can't
-- see anything useful about leaks in Instruments and the windows are certainly going away):
-- 16.848	Mimsy 	INFO	size = 24137 blocks
-- 18.878	Mimsy 	INFO	size = 24207 blocks
-- 20.902	Mimsy 	INFO	size = 21550 blocks
-- 22.917	Mimsy 	INFO	size = 21905 blocks
-- 24.935	Mimsy 	INFO	size = 22590 blocks
-- 26.958	Mimsy 	INFO	size = 23284 blocks
-- 28.970	Mimsy 	INFO	size = 23970 blocks
-- 31.000	Mimsy 	INFO	size = 24659 blocks
-- 33.012	Mimsy 	INFO	size = 25357 blocks
-- 35.025	Mimsy 	INFO	size = 25986 blocks
--
-- 3) The current approach is to check the instance counts for a few of the large objects
-- associated with new documents. This isn't ideal, but it is simple, reliable, and will catch
-- common high-impact ARC problems. 

max_count = 3
count = 0
doc = nil

-- TODO: it'd be nice to check a window or view but atm the only custom class
-- we have is TextView and, while it is going away, dealloc is not called.
stats = {}
stats['TextDocument'] = ftest:instancecount('TextDocument')
stats['TextController'] = ftest:instancecount('TextController')

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
function checkDoc()
	--app:log(string.format("numtextdocs = %d,  numcontrollers = %d", ftest:instancecount('TextDocument'), ftest:instancecount('TextController')))
	checkStats(0)
	
	if count < max_count then
		app:schedule(0.0, 'createDoc')
	else
		ftest:passed()
	end
end

function closeDoc()
	checkStats(1)
	doc:close()
	app:schedule(1.0, 'checkDoc')
end

function createDoc()
	doc = app:newdoc()
	count = count + 1
	app:schedule(2.0, 'closeDoc')
end

app:schedule(0.0, 'createDoc')
