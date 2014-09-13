-- Intercept option-tab (and shift-option-tab) and select the next (or previous) identifier.

function init()
	mimsy:set_extension_name("option-tab")
	mimsy:set_extension_version("1.0")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/keydown/text-editor/option-tab/pressed", "onOptionTab")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/keydown/text-editor/option-shift-tab/pressed", "onOptionShiftTab")
end

function log(text)
	write_file("log/line", "OptionTab:" .. text)
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

function tab(delta)
	local handled = false

	local elements = read_file("text-window/1/element-names")
	if elements ~= "" then
		local lines = split(elements, "\n")
		local selection_index = lines[1] + 2	-- +2 because lua arrays are 1-based and we skip the first line

		-- lines are formatted as "<element name>:<location>:<length>"
		local line = selection_index + delta
		while line >= 1 and line <= #lines do
			local parts = split(lines[line], ":")
			if parts[1] == "identifier" then
				write_file("text-window/1/selection-range", string.format("%d:%d", parts[2], parts[3]))
				break
			end
			line = line + delta
		end

		if line > #lines then
			write_file("beep", "")
		end

		handled = true
	end

	return handled
end

function onOptionTab()
	return tab(1)
end

function onOptionShiftTab()
	return tab(-1)
end
