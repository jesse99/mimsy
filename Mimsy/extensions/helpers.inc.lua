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
	local start = 1
	local splitStart, splitEnd = string.find(str, pattern, start)
	while splitStart do
		table.insert(results, string.sub(str, start, splitStart-1))
		start = splitEnd + 1
		splitStart, splitEnd = string.find(str, pattern, start)
	end
	table.insert(results, string.sub(str, start))
	return results
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

-- Writes a formatted string into Mimsy's log file which normally lands at
-- ~/Library/Logs/mimsy.log.
function log(format, ...)
	local text = string.format(format, unpack(arg))
	write_proc_file("/log/line", string.format("highlight-line\f%s", text))
end

-- Need to return a value because this file is typically loaded via `assert(dofile(...))`.
return true
