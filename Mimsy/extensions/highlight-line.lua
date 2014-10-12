-- Set the back color of the current line.

function init()
	mimsy:set_extension_name("highlight-line")
	mimsy:set_extension_version("1.0")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/text-window/1/line-number", "onLineChanged")
end

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

function read_file(path)
	local file, err = io.open("/Volumes/Mimsy/" .. path, "r")
	assert(file, string.format("failed to open %s: %q", path, err and err or "nil"))
	local contents = file:read("*a")
	io.close(file)
	return contents
end

function write_file(path, text)
	local file, err = io.open("/Volumes/Mimsy/" .. path, "w")
	assert(file, string.format("failed to open %s: %q", path, err and err or "nil"))
	file:write(text)
	io.close(file)
end

function log(format, ...)
	local text = string.format(format, unpack(arg))
	write_file("/log/line", string.format("highlight-line\f%s", text))
end

function onLineChanged()
	local line = read_file("text-window/1/line-number")
	--log("line = %s", line)
	if line ~= "-1" then
		local new_text = read_file("text-window/1/line-selection")
		local old_text = read_file("text-window/1/key-values/highlight-line-selection")
		--log("new_text = %s, old_text = %s", new_text, old_text)
		if new_text ~= old_text then
			if old_text ~= "" then
				local old_selection = split(old_text, "\f")
				write_file("text-window/1/remove-temp-back-color", string.format("%d\f%d", old_selection[1], old_selection[2]))
			end

			local new_selection = split(new_text, "\f")
			write_file("text-window/1/add-temp-back-color", string.format("%d\f%d\fSkyBlue", new_selection[1], new_selection[2]))
			write_file("text-window/1/key-values/highlight-line-selection", new_text)
		end
	else
		local old_text = read_file("text-window/1/key-values/highlight-line-selection")
		--log("old_text = %s", old_text)
		if old_text ~= "" then
			local old_selection = split(old_text, "\f")
			write_file("text-window/1/remove-temp-back-color", string.format("%d\f%d", old_selection[1], old_selection[2]))
			write_file("text-window/1/key-values/highlight-line-selection", "")
		end
	end

	return false
end
