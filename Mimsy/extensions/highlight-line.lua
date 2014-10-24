-- Set the back color of the current line.

color = "PeachPuff"

function init()
	mimsy:set_extension_name("highlight-line")
	mimsy:set_extension_version("1.0")
	
	-- Temporary attributes are a bit annoying because they don't affect the typing attributes
	-- so edits don't look right. It'd be possible to use normal attributes but then we'd have
	-- somehow remove them before saving and copying. So, for now, we just re-apply the line
	-- highlighting after normal styles are applied to fix the line up.
	mimsy:watch_file(1.0, "/Volumes/Mimsy/extension-settings-changed", "load_prefs")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/line-number", "onLineChanged")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/applied-styles", "onLineChanged")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/text-document/main-changed", "onMainChanged")

	load_prefs()
end

function load_prefs()
	function save_default_prefs(path)
		local file, err = io.open(path, "w")
		file:write(string.format([==[
prefs = {
	-- This is the background line color. Standard Mimsy
	-- color names may be used.
	color = "%s"
}
]==], color))
		io.close(file)
	end
	
	local settings = read_file("extension-settings")
	if settings then
		local path = settings .. "/highlight-line.lua"
		local file, _ = io.open(path, "r")
		if not file then
			save_default_prefs(path)
			file, _ = io.open(path, "r")
		end
		
		if file then
			io.close(file)
			dofile(path)
			color = prefs.color
		end
	end
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
	local line = read_file("text-document/line-number")
	--log("line = %s", line)
	if line ~= "-1" then
		local new_text = read_file("text-document/line-selection")
		local old_text = read_file("text-document/key-values/highlight-line-selection")
		--log("new_text = %s, old_text = %s", new_text, old_text)
		if new_text ~= old_text then
			if old_text ~= "" then
				local old_selection = split(old_text, "\f")
				write_file("text-document/remove-temp-back-color", string.format("%d\f%d", old_selection[1], old_selection[2]))
			end

			local new_selection = split(new_text, "\f")
			write_file("text-document/add-temp-back-color", string.format("%d\f%d\f%s", new_selection[1], new_selection[2], color))
			write_file("text-document/key-values/highlight-line-selection", new_text)
		end
	else
		local old_text = read_file("text-document/key-values/highlight-line-selection")
		--log("old_text = %s", old_text)
		if old_text ~= "" then
			local old_selection = split(old_text, "\f")
			write_file("text-document/remove-temp-back-color", string.format("%d\f%d", old_selection[1], old_selection[2]))
			write_file("text-document/key-values/highlight-line-selection", "")
		end
	end

	return false
end

function onMainChanged()
    write_file("text-document/remove-temp-back-color", "0\f100000")
    write_file("text-document/key-values/highlight-line-selection", "")
    onLineChanged()
end
