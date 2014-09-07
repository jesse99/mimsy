-- Intercept option-tab (and shift-option-tab) and select the next (or previous) identifier.

function init()
	mimsy:set_extension_name("option-tab")
	mimsy:set_extension_version("1.0")
	mimsy:watch_file(1.0, "/mimsy/keydown/text-editor/tab/pressed", "onOptionTab")
end

function onOptionTab()
	local file, err = io.open("/Volumes/Mimsy/log/line", "w")
	assert(file, err)
	file:write("App:tabbed")
	io.close(file)

	return false
end
