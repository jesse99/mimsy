-- Misc helper functions for use by lua extensions.

-- Returns preference data. file_name will typically be the name of the extension appended with ".lua".
-- defaults should be a string containing a table literal bound to a variable named prefs. The prefs table
-- is returned. In the event of an error nil is returned.
function load_prefs_helper(file_name, defaults)
	function save_default_prefs(path, defaults)
		local file, err = io.open(path, "w")
		file:write(defaults)
		io.close(file)
	end

	local settings = read_proc_file("extension-settings")
	if settings then
		local path = settings .. "/" .. file_name
		local file, _ = io.open(path, "r")
		if not file then
			save_default_prefs(path, defaults)
			file, _ = io.open(path, "r")
		end

		if file then
			io.close(file)
			dofile(path)
			return prefs
		end
	end

    return nil
end

-- Returns a table with numeric indexes containing the string split using pattern.
-- Typically the pattern will be "\f" because that is what Mimsy uses as a record
-- separator within proc files, but the pattern can be any regex.
function split(str, pattern)
	results = {}
    if str ~= nil then
        --log("splitting ", str, " using ", pattern)
        local start = 1
        local splitStart, splitEnd = string.find(str, pattern, start)
        while splitStart do
            --log("   adding ", string.sub(str, start, splitStart-1))
            table.insert(results, string.sub(str, start, splitStart-1))
            start = splitEnd + 1
            splitStart, splitEnd = string.find(str, pattern, start)
        end

        local last = string.sub(str, start)
        if #last > 0 then
            --log("   adding ", last)
            table.insert(results, last)
        end
    end
	return results
end

-- Returns the last index of the needle string within text or nil 
-- if needle was not found.
function rfind(text, needle)
	if string.len(needle) <= string.len(text) then
		for index = string.len(text) - string.len(needle) + 1, 1, -1 do
			if string.sub(text, index, index + string.len(needle) - 1) == needle then
				return index
			end
		end
	end
	return nil
end

-- Returns the directory component of a full path or nil.
function directory_path(path)
	local i = rfind(path, "/")
	if i ~= nil then
        return string.sub(path, 1, i - 1)
	else
		return nil
	end
end

-- Returns the file name component of a full path or nil.
function file_name(path)
	local i = rfind(path, "/")
	if i ~= nil then
		return string.sub(path, i + 1, string.len(path) - i)
	else
		return nil
	end
end

-- Returns true if the path is a readable file.
function fileExists(path)
    -- Usually something like stat would be used but the facilities lua provides
    -- are very limited.
    local file = io.open(path, "r")
    if file == nil then
        return false
    else
        io.close(file)
        return true
    end
end

-- Returns the contents of a proc file as a string.
function read_proc_file(path)
	local file, err = io.open("/Volumes/Mimsy/" .. path, "r")
	assert(file, string.format("failed to open %s: %q", path, err and err or "nil"))
	local contents = file:read("*a")
	io.close(file)
	return contents
end

-- Writes text into a proc file.
function write_proc_file(path, text)
	local file, err = io.open("/Volumes/Mimsy/" .. path, "w")
	assert(file, string.format("failed to open %s: %q", path, err and err or "nil"))
	file:write(text)
	io.close(file)
end

inspect = nil

-- Concatenates the arguments and writes the result to Mimsy's log file which normally
-- lands at ~/Library/Logs/mimsy.log.
function log(...)
    local text = ""

    for i = 1, select("#", ...) do
        local arg = select(i, ...)
        if type(arg) == 'string' then
            text = text .. arg
        else
            text = text .. inspect(arg)
        end
    end

    write_proc_file("/log/line", string.format("lua\f%s", text))
end

-- Need to return a value because this file is typically loaded via `assert(dofile(...))`.
return true
