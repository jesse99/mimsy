-- Verify that Mimsy refuses to open files for which it cannot determine the encoding (tho
-- they can be opened as binary).
function openedDoc(doc)
	ftest:failed('doc opened')
end

function openFailed(reason)
	ftest:passed()
end

local fname = '/tmp/malformed.txt'
local file = io.open(fname, 'w')
file:write('\137\80\78\71\13\10\26\10\0\0\0\13\73\72\68\82')	-- first 16 bytes of an ico file
file:close(file)

app:openfile(fname, 'openedDoc', 'openFailed')
