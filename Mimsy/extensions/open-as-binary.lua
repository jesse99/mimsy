-- Adds a context menu item to directory windows to show the content of files as binary data.
function init(script_dir)
	mimsy:set_extension_name("open-as-binary")
	mimsy:set_extension_version("1.0")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/directory/menu-action", "onMenuAction")
	mimsy:watch_file(1.0, "/Volumes/Mimsy/directory/menu-selection", "onMenuSelection")

	assert(dofile(script_dir .. "/helpers.inc.lua"))
    inspect = dofile(script_dir .. "/inspect.inc.lua")
    dofile(script_dir .. "/base64.inc.lua")
end

function onMenuSelection()
	local elements = read_proc_file("directory/menu-selection")
	local lines = split(elements, "\n")
	local files = split(lines[1], "\f")

    if #files > 0 then
		write_proc_file("directory/menu-content", "Open as Binary\nopen-as-binary")
	end
end

function onMenuAction()
    local elements = read_proc_file("directory/menu-action")
    local lines = split(elements, "\n")
    if lines[1] == "open-as-binary" then
        local files = split(lines[2], "\f")
        for i, file in ipairs(files) do
            local procFile = string.format("actions/open-as-binary/%s", to_base64(file))
            local text = read_proc_file(procFile)
            local result = split(text, "\f")
            if result[1] ~= "0" then
                log("Failed to open as binary '", file, "': ", result[2])
                write_proc_file("beep", "1")
            end
        end
    end
end
